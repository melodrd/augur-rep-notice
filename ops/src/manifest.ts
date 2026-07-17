// Deterministic recipient-manifest tooling for MigrateRepV2Token (MREP2).
//
// This module prepares an off-chain distribution plan from a list of recipient addresses and the
// human-supplied provenance of that list. It validates and normalizes addresses, rejects zero and
// duplicate addresses, sorts by a single documented canonical rule, splits into batches no larger
// than the operational batch size, and records exact cumulative recipient counts, the expected
// remaining initial allocation after each batch, and cryptographic checksums.
//
// The recipient cap is DERIVED from the final normalized unique recipient list; it is never
// supplied by the caller. A production manifest therefore cannot contain discretionary capacity:
// there is no way to request supply or distribution headroom beyond the disclosed recipients.
//
// It never repairs a malformed address, never invents recipients or provenance, never stores
// personal data, and performs no signing, broadcasting, or network access. On-chain duplicate
// protection remains authoritative even though this manifest is deduplicated.

import { createHash } from "node:crypto";
import { getAddress, isAddress } from "viem";
import { z } from "zod";

/** One whole MREP2 token in base units (18 decimals). */
export const TOKEN_PER_RECIPIENT = 1_000_000_000_000_000_000n;

/** Hard on-chain batch ceiling. The operational batch size must not exceed this. */
export const MAX_BATCH_SIZE = 200;

/**
 * Manifest schema version.
 *
 * v2 derives `recipientCap` from the recipient list, requires `provenance`, renames
 * `inputChecksum` to `canonicalRecipientsChecksum`, and renames `expectedReserveAfter` to
 * `expectedRemainingInitialAllocationAfter`. Field names and semantics both changed, so v1
 * manifests are not forward-compatible and must be regenerated.
 */
export const MANIFEST_SCHEMA_VERSION = 2;

const SORT_RULE = "ascending lowercase 20-byte hex address";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

/** `sha256:` followed by 64 lowercase hex characters. */
const SHA256_CHECKSUM = /^sha256:[0-9a-f]{64}$/;

/** A 32-byte hash in hex. */
const BLOCK_HASH = /^0x[0-9a-fA-F]{64}$/;

/** A canonical base-10 integer with no sign, leading zeros, or separators. */
const DECIMAL_INTEGER = /^(0|[1-9][0-9]*)$/;

/**
 * Where a recipient list came from and which rules produced it. Every value is supplied by a
 * human and recorded verbatim; this module never derives, defaults, or invents any of it.
 *
 * Large integers are strings because JSON numbers cannot safely carry them.
 */
export interface RecipientProvenance {
  /** EIP-155 chain ID of the chain the snapshot was taken from. */
  chainId: number;
  /** Snapshot block number, base-10. A string to avoid JSON numeric-precision loss. */
  snapshotBlockNumber: string;
  /** 32-byte hash of the snapshot block, pinning the snapshot to one exact chain history. */
  snapshotBlockHash: `0x${string}`;
  /** The REP/REPv2 (or other) contracts the balances were read from, in reviewed order. */
  sourceContracts: `0x${string}`[];
  /** Checksum of the frozen source data itself, as extracted before any transformation. */
  sourceDataChecksum: string;
  /** Identifier of the approved eligibility ruleset that produced the list. */
  rulesetId: string;
  /** Checksum of that ruleset, pinning which exact rules were applied. */
  rulesetChecksum: string;
}

export interface BuildOptions {
  /** Operational batch size (1..MAX_BATCH_SIZE). */
  batchSize: number;
  /** Mandatory human-supplied provenance for the recipient list. */
  provenance: RecipientProvenance;
}

export interface Batch {
  batchNumber: number;
  recipientCount: number;
  firstAddress: `0x${string}`;
  lastAddress: `0x${string}`;
  batchChecksum: string;
  cumulativeRecipients: number;
  /**
   * Base units of the original initial allocation still undistributed after this batch:
   * `(recipientCap - cumulativeRecipients) * TOKEN_PER_RECIPIENT`.
   *
   * This is NOT the expected live balance of the token contract. MREP2 is freely transferable,
   * so holders may transfer tokens back to `address(token)`, and the live contract balance can
   * therefore be larger than this figure. See the note on {Manifest}.
   */
  expectedRemainingInitialAllocationAfter: string;
  recipients: `0x${string}`[];
}

/**
 * A deterministic, reviewable distribution manifest.
 *
 * Two quantities must never be conflated:
 *
 * - **remaining initial allocation** — `(recipientCap - cumulativeRecipients) * TOKEN_PER_RECIPIENT`,
 *   an off-chain projection of the original allocation not yet distributed. This manifest records
 *   it per batch as `expectedRemainingInitialAllocationAfter`.
 * - **live token contract balance** — `balanceOf(address(token))` on chain, which may exceed the
 *   remaining initial allocation by any amount holders transfer back to the contract.
 *
 * This manifest describes only the former. It cannot predict the latter.
 */
export interface Manifest {
  schemaVersion: number;
  provenance: RecipientProvenance;
  tokenPerRecipient: string;
  /** Derived from the final unique recipient list; equal to the number of recipients. */
  recipientCap: string;
  operationalBatchSize: number;
  maximumSupply: string;
  canonicalSortRule: string;
  /**
   * Checksum of the canonical (normalized, deduplicated, sorted, EIP-55 checksummed) recipient
   * array as it appears in this manifest.
   *
   * It proves the recipient array in this manifest is the one that was reviewed. It does NOT
   * prove the original source data was unchanged — it is computed after normalization and
   * sorting, not over the original input bytes. Use `provenance.sourceDataChecksum` for that.
   */
  canonicalRecipientsChecksum: string;
  manifestChecksum: string;
  batches: Batch[];
}

function sha256(data: string): string {
  return `sha256:${createHash("sha256").update(data, "utf8").digest("hex")}`;
}

const provenanceSchema = z.object({
  chainId: z
    .number()
    .int("chainId must be an integer")
    .positive("chainId must be positive"),
  snapshotBlockNumber: z
    .string()
    .regex(
      DECIMAL_INTEGER,
      "snapshotBlockNumber must be a base-10 integer string",
    )
    // Zod reports every failing check, so this must tolerate a value that already failed the
    // format check rather than throwing inside BigInt().
    .refine(
      (value) => DECIMAL_INTEGER.test(value) && BigInt(value) > 0n,
      "snapshotBlockNumber must be positive",
    ),
  snapshotBlockHash: z
    .string()
    .regex(BLOCK_HASH, "snapshotBlockHash must be a 32-byte 0x-prefixed hash"),
  sourceContracts: z
    .array(z.string())
    .min(1, "at least one source contract is required")
    .refine(
      (values) => values.every((value) => isAddress(value)),
      "every source contract must be a valid Ethereum address",
    )
    .refine(
      (values) => values.every((value) => value.toLowerCase() !== ZERO_ADDRESS),
      "a source contract must not be the zero address",
    )
    .refine((values) => {
      const lowered = values.map((value) => value.toLowerCase());
      return new Set(lowered).size === lowered.length;
    }, "source contracts must not contain duplicates"),
  sourceDataChecksum: z
    .string()
    .regex(
      SHA256_CHECKSUM,
      "sourceDataChecksum must look like sha256:<64 lowercase hex>",
    ),
  rulesetId: z.string().min(1, "rulesetId must not be empty"),
  rulesetChecksum: z
    .string()
    .regex(
      SHA256_CHECKSUM,
      "rulesetChecksum must look like sha256:<64 lowercase hex>",
    ),
});

/**
 * Validate provenance and return it in canonical form. Source contracts are EIP-55 checksummed
 * and the block hash is lowercased, so equivalent provenance always produces one checksum.
 * Source-contract order is preserved: it is reviewed input, and it is covered by the checksum.
 */
export function normalizeProvenance(raw: unknown): RecipientProvenance {
  const parsed = provenanceSchema.safeParse(raw);
  if (!parsed.success) {
    const detail = parsed.error.issues
      .map(
        (issue) => `${issue.path.join(".") || "provenance"}: ${issue.message}`,
      )
      .join("; ");
    throw new Error(`invalid recipient provenance: ${detail}`);
  }

  const value = parsed.data;
  return {
    chainId: value.chainId,
    snapshotBlockNumber: value.snapshotBlockNumber,
    snapshotBlockHash: value.snapshotBlockHash.toLowerCase() as `0x${string}`,
    sourceContracts: value.sourceContracts.map(
      (contract) => getAddress(contract) as `0x${string}`,
    ),
    sourceDataChecksum: value.sourceDataChecksum,
    rulesetId: value.rulesetId,
    rulesetChecksum: value.rulesetChecksum,
  };
}

/**
 * Validate, normalize, deduplicate, and sort recipient addresses.
 * Throws on any malformed address, the zero address, or a duplicate. Never repairs input.
 */
export function normalizeRecipients(raw: readonly string[]): `0x${string}`[] {
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
    const priorIndex = seen.get(lower);
    if (priorIndex !== undefined) {
      throw new Error(
        `duplicate address at index ${index} (first seen at ${priorIndex}): ${lower}`,
      );
    }
    seen.set(lower, index);
    // getAddress returns the EIP-55 checksummed form for human-facing output.
    checksummed.push(getAddress(entry));
  });

  // Canonical rule: sort by lowercase hex ascending.
  return checksummed.sort((left, right) => {
    const a = left.toLowerCase();
    const b = right.toLowerCase();
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
  });
}

/**
 * Build a deterministic manifest from raw recipient addresses and their provenance. Pure: no I/O,
 * no mutation of inputs, and the same inputs always produce the same output including checksums.
 *
 * `recipientCap` is derived from the final unique recipient list and cannot be supplied. The
 * deployed `MREP2_RECIPIENT_CAP` must be copied exactly from the approved manifest.
 */
export function buildManifest(
  raw: readonly string[],
  options: BuildOptions,
): Manifest {
  const { batchSize } = options;

  if (
    !Number.isInteger(batchSize) ||
    batchSize < 1 ||
    batchSize > MAX_BATCH_SIZE
  ) {
    throw new Error(
      `batchSize must be an integer in 1..${MAX_BATCH_SIZE}, got ${batchSize}`,
    );
  }

  const provenance = normalizeProvenance(options.provenance);
  const recipients = normalizeRecipients(raw);

  if (recipients.length === 0) {
    throw new Error(
      "recipient list is empty: a production manifest must distribute to at least one address",
    );
  }

  // The cap IS the disclosed recipient count. No headroom can be requested.
  const recipientCap = BigInt(recipients.length);
  const maximumSupply = recipientCap * TOKEN_PER_RECIPIENT;

  const batches: Batch[] = [];
  let cumulative = 0;
  for (let offset = 0; offset < recipients.length; offset += batchSize) {
    const slice = recipients.slice(offset, offset + batchSize);
    cumulative += slice.length;
    const expectedRemainingInitialAllocationAfter =
      (recipientCap - BigInt(cumulative)) * TOKEN_PER_RECIPIENT;
    const batchNumber = batches.length + 1;
    const batchBody = JSON.stringify({ batchNumber, recipients: slice });

    // biome-ignore lint/style/noNonNullAssertion: slice is non-empty by loop construction.
    const firstAddress = slice[0]!;
    // biome-ignore lint/style/noNonNullAssertion: slice is non-empty by loop construction.
    const lastAddress = slice[slice.length - 1]!;

    batches.push({
      batchNumber,
      recipientCount: slice.length,
      firstAddress,
      lastAddress,
      batchChecksum: sha256(batchBody),
      cumulativeRecipients: cumulative,
      expectedRemainingInitialAllocationAfter:
        expectedRemainingInitialAllocationAfter.toString(10),
      recipients: slice,
    });
  }

  const canonicalRecipientsChecksum = sha256(JSON.stringify(recipients));

  const withoutManifestChecksum: Omit<Manifest, "manifestChecksum"> = {
    schemaVersion: MANIFEST_SCHEMA_VERSION,
    provenance,
    tokenPerRecipient: TOKEN_PER_RECIPIENT.toString(10),
    recipientCap: recipientCap.toString(10),
    operationalBatchSize: batchSize,
    maximumSupply: maximumSupply.toString(10),
    canonicalSortRule: SORT_RULE,
    canonicalRecipientsChecksum,
    batches,
  };

  // The manifest checksum covers the schema version, provenance, token-per-recipient, recipient
  // cap, maximum supply, batch size, sort rule, canonical recipient checksum, and every batch.
  return {
    ...withoutManifestChecksum,
    manifestChecksum: sha256(JSON.stringify(withoutManifestChecksum)),
  };
}

/** Deterministic pretty JSON serialization. */
export function manifestToJson(manifest: Manifest): string {
  return `${JSON.stringify(manifest, null, 2)}\n`;
}

/** Reviewable CSV: one row per recipient with batch number, position, and checksummed address. */
export function manifestToCsv(manifest: Manifest): string {
  const rows: string[] = [
    "batch_number,position_in_batch,cumulative_index,address",
  ];
  let cumulativeIndex = 0;
  for (const batch of manifest.batches) {
    batch.recipients.forEach((address, position) => {
      cumulativeIndex += 1;
      rows.push(
        `${batch.batchNumber},${position + 1},${cumulativeIndex},${address}`,
      );
    });
  }
  return `${rows.join("\n")}\n`;
}
