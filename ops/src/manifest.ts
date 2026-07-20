// Deterministic recipient-manifest tooling for MigrateRepV2Token (CHECKAUGUR).
//
// A manifest is an offline, human-approved artifact: the exact set of addresses that will each
// receive one CHECKAUGUR token, plus the provenance of how that set was chosen. The contract never
// reads it. It exists so the recipient list can be reviewed, checksummed, and frozen before any
// deployment, and so the deployed cap is derived from the list rather than chosen with headroom.
//
// This module validates and normalizes addresses, rejects the zero address and case-insensitive
// duplicates, sorts deterministically by lowercase address, and derives the cap and supply from
// the exact unique recipient count. It never repairs input, invents provenance, stores personal
// data, signs, broadcasts, or touches the network. On-chain duplicate protection stays
// authoritative even though the manifest is already deduplicated.

import { getAddress, isAddress } from "viem";

/** One whole CHECKAUGUR token in base units (18 decimals). */
export const TOKEN_PER_RECIPIENT = 1_000_000_000_000_000_000n;

/** Hard on-chain per-call recipient ceiling; the batch size must not exceed it. */
export const MAX_BATCH_SIZE = 200;

/** The only manifest format this tool reads or writes. There is no v2 and no migration path. */
export const MANIFEST_VERSION = 1;

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

/** `sha256:` followed by 64 lowercase hex characters. */
const SHA256 = /^sha256:[0-9a-f]{64}$/;

/** A 32-byte hash in hex. */
const BLOCK_HASH = /^0x[0-9a-fA-F]{64}$/;

/** A canonical base-10 integer with no sign, leading zeros, or separators. */
const DECIMAL = /^(0|[1-9][0-9]*)$/;

/**
 * Where a recipient list came from and which rules produced it. Every field is human-supplied and
 * recorded verbatim; the tool validates its shape but never derives, defaults, or invents any of
 * it, and cannot confirm it describes a real snapshot.
 *
 * `sourceChainId` is the chain the snapshot was read from. It is deliberately independent of the
 * plan's `targetChainId` (where CHECKAUGUR is deployed): a mainnet snapshot may drive a Sepolia
 * rehearsal, so the two are never required to match.
 *
 * Large integers are strings because JSON numbers cannot safely carry them.
 */
export interface Provenance {
  sourceChainId: number;
  snapshotBlockNumber: string;
  snapshotBlockHash: `0x${string}`;
  sourceContracts: `0x${string}`[];
  sourceDataSha256: string;
  rulesetId: string;
  rulesetSha256: string;
}

/**
 * The lean manifest. It stores only authoritative inputs: nothing that can be derived cheaply from
 * `recipients` (cap, supply, batch counts, checksums) is kept here — those are computed on demand.
 */
export interface Manifest {
  version: number;
  provenance: Provenance;
  batchSize: number;
  /** Canonical: EIP-55 checksummed, deduplicated, sorted ascending by lowercase address. */
  recipients: `0x${string}`[];
}

export interface Batch {
  number: number;
  recipients: `0x${string}`[];
}

function requireString(value: unknown, label: string): string {
  if (typeof value !== "string") {
    throw new Error(`${label} must be a string`);
  }
  return value;
}

/**
 * Validate provenance and return it in canonical form: source contracts EIP-55 checksummed, block
 * hash lowercased. Source-contract order is preserved because it is reviewed input.
 */
export function parseProvenance(raw: unknown): Provenance {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw new Error("invalid recipient provenance: expected an object");
  }
  const p = raw as Record<string, unknown>;

  const sourceChainId = p.sourceChainId;
  if (
    typeof sourceChainId !== "number" ||
    !Number.isInteger(sourceChainId) ||
    sourceChainId <= 0
  ) {
    throw new Error("provenance.sourceChainId must be a positive integer");
  }

  const snapshotBlockNumber = requireString(
    p.snapshotBlockNumber,
    "provenance.snapshotBlockNumber",
  );
  if (!DECIMAL.test(snapshotBlockNumber) || BigInt(snapshotBlockNumber) <= 0n) {
    throw new Error(
      "provenance.snapshotBlockNumber must be a positive base-10 integer string",
    );
  }

  const snapshotBlockHash = requireString(
    p.snapshotBlockHash,
    "provenance.snapshotBlockHash",
  );
  if (!BLOCK_HASH.test(snapshotBlockHash)) {
    throw new Error(
      "provenance.snapshotBlockHash must be a 32-byte 0x-prefixed hash",
    );
  }

  if (!Array.isArray(p.sourceContracts) || p.sourceContracts.length === 0) {
    throw new Error("provenance.sourceContracts must be a non-empty array");
  }
  const seenContracts = new Set<string>();
  const sourceContracts = p.sourceContracts.map((entry, i) => {
    if (typeof entry !== "string" || !isAddress(entry)) {
      throw new Error(
        `provenance.sourceContracts[${i}] must be a valid Ethereum address`,
      );
    }
    const lower = entry.toLowerCase();
    if (lower === ZERO_ADDRESS) {
      throw new Error(
        `provenance.sourceContracts[${i}] must not be the zero address`,
      );
    }
    if (seenContracts.has(lower)) {
      throw new Error(
        `provenance.sourceContracts[${i}] is a duplicate: ${entry}`,
      );
    }
    seenContracts.add(lower);
    return getAddress(entry);
  });

  const sourceDataSha256 = requireString(
    p.sourceDataSha256,
    "provenance.sourceDataSha256",
  );
  if (!SHA256.test(sourceDataSha256)) {
    throw new Error(
      "provenance.sourceDataSha256 must look like sha256:<64 lowercase hex>",
    );
  }

  const rulesetId = requireString(p.rulesetId, "provenance.rulesetId");
  if (rulesetId.length === 0) {
    throw new Error("provenance.rulesetId must not be empty");
  }

  const rulesetSha256 = requireString(
    p.rulesetSha256,
    "provenance.rulesetSha256",
  );
  if (!SHA256.test(rulesetSha256)) {
    throw new Error(
      "provenance.rulesetSha256 must look like sha256:<64 lowercase hex>",
    );
  }

  return {
    sourceChainId,
    snapshotBlockNumber,
    snapshotBlockHash: snapshotBlockHash.toLowerCase() as `0x${string}`,
    sourceContracts,
    sourceDataSha256,
    rulesetId,
    rulesetSha256,
  };
}

/**
 * Validate, normalize, deduplicate, and sort a raw recipient list. Throws on any malformed
 * address, the zero address, or a case-insensitive duplicate. Never repairs input.
 */
export function normalizeRecipients(raw: readonly unknown[]): `0x${string}`[] {
  const seen = new Map<string, number>();
  const checksummed: `0x${string}`[] = [];

  raw.forEach((entry, index) => {
    if (typeof entry !== "string" || !isAddress(entry)) {
      throw new Error(
        `invalid Ethereum address at index ${index}: ${String(entry)}`,
      );
    }
    const lower = entry.toLowerCase();
    if (lower === ZERO_ADDRESS) {
      throw new Error(`zero address at index ${index}`);
    }
    const prior = seen.get(lower);
    if (prior !== undefined) {
      throw new Error(
        `duplicate address at index ${index} (first seen at ${prior}): ${lower}`,
      );
    }
    seen.set(lower, index);
    checksummed.push(getAddress(entry));
  });

  return checksummed.sort((a, b) => {
    const la = a.toLowerCase();
    const lb = b.toLowerCase();
    if (la < lb) return -1;
    if (la > lb) return 1;
    return 0;
  });
}

function assertBatchSize(batchSize: number): void {
  if (
    !Number.isInteger(batchSize) ||
    batchSize < 1 ||
    batchSize > MAX_BATCH_SIZE
  ) {
    throw new Error(
      `batchSize must be an integer in 1..${MAX_BATCH_SIZE}, got ${batchSize}`,
    );
  }
}

/**
 * Build a manifest from a raw recipient list and its provenance. Pure: no I/O, no mutation of
 * inputs, and the same inputs always produce the same manifest. The cap is the disclosed recipient
 * count and cannot be supplied, so a manifest cannot carry undisclosed headroom.
 */
export function buildManifest(
  rawRecipients: readonly unknown[],
  provenance: unknown,
  batchSize: number,
): Manifest {
  assertBatchSize(batchSize);
  const parsedProvenance = parseProvenance(provenance);
  const recipients = normalizeRecipients(rawRecipients);
  if (recipients.length === 0) {
    throw new Error(
      "recipient list is empty: a manifest must distribute to at least one address",
    );
  }
  return {
    version: MANIFEST_VERSION,
    provenance: parsedProvenance,
    batchSize,
    recipients,
  };
}

/**
 * Recipients in a stored manifest must already be canonical: valid, non-zero, EIP-55 checksummed,
 * and strictly ascending by lowercase address. Strict ascending order rejects unsorted lists and
 * case-insensitive duplicates in one check. A hand-edited or corrupted list is rejected rather
 * than silently re-normalized, so the reviewed array is the array that reaches calldata generation.
 */
function parseCanonicalRecipients(raw: readonly unknown[]): `0x${string}`[] {
  if (raw.length === 0) {
    throw new Error("manifest.recipients must not be empty");
  }
  let previousLower: string | undefined;
  return raw.map((entry, index) => {
    if (typeof entry !== "string" || !isAddress(entry)) {
      throw new Error(
        `recipient at index ${index} is not a valid Ethereum address: ${String(entry)}`,
      );
    }
    if (getAddress(entry) !== entry) {
      throw new Error(
        `recipient at index ${index} is not in canonical EIP-55 checksummed form: ${entry}`,
      );
    }
    const lower = entry.toLowerCase();
    if (lower === ZERO_ADDRESS) {
      throw new Error(`recipient at index ${index} is the zero address`);
    }
    if (previousLower !== undefined) {
      if (lower === previousLower) {
        throw new Error(`duplicate recipient at index ${index}: ${entry}`);
      }
      if (lower < previousLower) {
        throw new Error(
          `recipients are not sorted ascending at index ${index}: ${entry}`,
        );
      }
    }
    previousLower = lower;
    return entry as `0x${string}`;
  });
}

/**
 * Validate a manifest loaded from untrusted storage (a JSON file) and return it normalized.
 * Nothing is trusted on the strength of its TypeScript type: version, provenance, batch size, and
 * every recipient are checked. Byte-level integrity is a separate concern, covered by the detached
 * `manifest.json.sha256` the CLI emits.
 */
export function parseManifest(raw: unknown): Manifest {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw new Error("manifest must be a JSON object");
  }
  const m = raw as Record<string, unknown>;

  if (m.version !== MANIFEST_VERSION) {
    throw new Error(
      `unsupported manifest version: expected ${MANIFEST_VERSION}, got ${String(m.version)}`,
    );
  }

  const provenance = parseProvenance(m.provenance);

  if (typeof m.batchSize !== "number") {
    throw new Error("manifest.batchSize must be a number");
  }
  assertBatchSize(m.batchSize);

  if (!Array.isArray(m.recipients)) {
    throw new Error("manifest.recipients must be an array");
  }
  const recipients = parseCanonicalRecipients(m.recipients);

  return {
    version: MANIFEST_VERSION,
    provenance,
    batchSize: m.batchSize,
    recipients,
  };
}

/** Derived: the recipient cap equals the exact unique recipient count. */
export function recipientCap(manifest: Manifest): bigint {
  return BigInt(manifest.recipients.length);
}

/** Derived: `recipientCap * TOKEN_PER_RECIPIENT`. */
export function maximumSupply(manifest: Manifest): bigint {
  return recipientCap(manifest) * TOKEN_PER_RECIPIENT;
}

/** Split the canonical recipients into deterministic batches of at most `batchSize`. */
export function splitBatches(manifest: Manifest): Batch[] {
  const batches: Batch[] = [];
  for (
    let offset = 0;
    offset < manifest.recipients.length;
    offset += manifest.batchSize
  ) {
    batches.push({
      number: batches.length + 1,
      recipients: manifest.recipients.slice(
        offset,
        offset + manifest.batchSize,
      ),
    });
  }
  return batches;
}

/** Deterministic pretty JSON serialization with a trailing newline. */
export function manifestToJson(manifest: Manifest): string {
  return `${JSON.stringify(manifest, null, 2)}\n`;
}

/** Reviewable CSV: exactly one row per recipient, with the derived batch number and 1-based index. */
export function manifestToCsv(manifest: Manifest): string {
  const rows = ["batch,index,address"];
  let index = 0;
  for (const batch of splitBatches(manifest)) {
    for (const address of batch.recipients) {
      index += 1;
      rows.push(`${batch.number},${index},${address}`);
    }
  }
  return `${rows.join("\n")}\n`;
}
