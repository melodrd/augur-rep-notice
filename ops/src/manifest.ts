// Deterministic recipient-manifest tooling for MigrateRepV2Token (MREP2).
//
// This module prepares an off-chain distribution plan from a list of recipient addresses.
// It validates and normalizes addresses, rejects zero addresses and duplicates, sorts by a
// single documented canonical rule, splits into batches no larger than the operational batch
// size, and records exact cumulative recipient counts, the expected reserve after each batch,
// and cryptographic checksums.
//
// It never repairs a malformed address, never invents recipients, never stores personal data,
// and performs no signing, broadcasting, or network access. On-chain duplicate protection
// remains authoritative even though this manifest is deduplicated.

import { createHash } from "node:crypto";
import { getAddress, isAddress } from "viem";

/** One whole MREP2 token in base units (18 decimals). */
export const TOKEN_PER_RECIPIENT = 1_000_000_000_000_000_000n;

/** Hard on-chain batch ceiling. The operational batch size must not exceed this. */
export const MAX_BATCH_SIZE = 200;

export interface BuildOptions {
  /** Immutable recipient cap. The unique recipient count must not exceed this. */
  recipientCap: bigint;
  /** Operational batch size (1..MAX_BATCH_SIZE). */
  batchSize: number;
}

export interface Batch {
  batchNumber: number;
  recipientCount: number;
  firstAddress: `0x${string}`;
  lastAddress: `0x${string}`;
  batchChecksum: string;
  cumulativeRecipients: number;
  expectedReserveAfter: string;
  recipients: `0x${string}`[];
}

export interface Manifest {
  version: number;
  tokenPerRecipient: string;
  recipientCap: string;
  operationalBatchSize: number;
  totalRecipients: number;
  maximumSupply: string;
  canonicalSortRule: string;
  inputChecksum: string;
  manifestChecksum: string;
  batches: Batch[];
}

const SORT_RULE = "ascending lowercase 20-byte hex address";

function sha256(data: string): string {
  return `sha256:${createHash("sha256").update(data, "utf8").digest("hex")}`;
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
    if (lower === "0x0000000000000000000000000000000000000000") {
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
 * Build a deterministic manifest from raw recipient addresses. Pure: no I/O, no mutation of
 * inputs, and the same inputs always produce the same output including checksums.
 */
export function buildManifest(
  raw: readonly string[],
  options: BuildOptions,
): Manifest {
  const { recipientCap, batchSize } = options;

  if (
    !Number.isInteger(batchSize) ||
    batchSize < 1 ||
    batchSize > MAX_BATCH_SIZE
  ) {
    throw new Error(
      `batchSize must be an integer in 1..${MAX_BATCH_SIZE}, got ${batchSize}`,
    );
  }
  if (recipientCap <= 0n) {
    throw new Error(`recipientCap must be positive, got ${recipientCap}`);
  }

  const recipients = normalizeRecipients(raw);

  if (BigInt(recipients.length) > recipientCap) {
    throw new Error(
      `recipient count ${recipients.length} exceeds recipientCap ${recipientCap}`,
    );
  }

  const maximumSupply = recipientCap * TOKEN_PER_RECIPIENT;

  const batches: Batch[] = [];
  let cumulative = 0;
  for (let offset = 0; offset < recipients.length; offset += batchSize) {
    const slice = recipients.slice(offset, offset + batchSize);
    cumulative += slice.length;
    const expectedReserveAfter =
      maximumSupply - BigInt(cumulative) * TOKEN_PER_RECIPIENT;
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
      expectedReserveAfter: expectedReserveAfter.toString(10),
      recipients: slice,
    });
  }

  const inputChecksum = sha256(JSON.stringify(recipients));

  const withoutManifestChecksum: Omit<Manifest, "manifestChecksum"> = {
    version: 1,
    tokenPerRecipient: TOKEN_PER_RECIPIENT.toString(10),
    recipientCap: recipientCap.toString(10),
    operationalBatchSize: batchSize,
    totalRecipients: recipients.length,
    maximumSupply: maximumSupply.toString(10),
    canonicalSortRule: SORT_RULE,
    inputChecksum,
    batches,
  };

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
