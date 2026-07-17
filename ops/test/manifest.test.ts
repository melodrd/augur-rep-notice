import { describe, expect, test } from "bun:test";
import { getAddress } from "viem";
import {
  type BuildOptions,
  buildManifest,
  MANIFEST_SCHEMA_VERSION,
  MAX_BATCH_SIZE,
  manifestToCsv,
  manifestToJson,
  normalizeProvenance,
  normalizeRecipients,
  type RecipientProvenance,
  TOKEN_PER_RECIPIENT,
} from "../src/manifest.ts";

function addr(n: number): string {
  return `0x${n.toString(16).padStart(40, "0")}`;
}

const CHECKSUM_A = `sha256:${"a".repeat(64)}`;
const CHECKSUM_B = `sha256:${"b".repeat(64)}`;

/** Stand-in for a reviewed source contract. Not a proposed REP or REPv2 address. */
const SOURCE_CONTRACT = getAddress(addr(0xabc123)) as `0x${string}`;

/**
 * Explicit test fixture. Provenance is never invented by the tooling: these are stand-in values
 * for a reviewed snapshot, not a proposed REP snapshot, ruleset, or source contract.
 */
function provenance(
  overrides: Partial<RecipientProvenance> = {},
): RecipientProvenance {
  return {
    chainId: 1,
    snapshotBlockNumber: "21000000",
    snapshotBlockHash: `0x${"1".repeat(64)}`,
    sourceContracts: [SOURCE_CONTRACT],
    sourceDataChecksum: CHECKSUM_A,
    rulesetId: "fixture-ruleset-v1",
    rulesetChecksum: CHECKSUM_B,
    ...overrides,
  };
}

function build(recipients: readonly string[], batchSize: number) {
  return buildManifest(recipients, { batchSize, provenance: provenance() });
}

describe("normalizeRecipients", () => {
  test("sorts ascending by lowercase hex and checksums output", () => {
    const result = normalizeRecipients([addr(3), addr(1), addr(2)]);
    expect(result.map((a) => a.toLowerCase())).toEqual([
      addr(1),
      addr(2),
      addr(3),
    ]);
  });

  test("rejects a malformed address without repair", () => {
    expect(() => normalizeRecipients(["0x123"])).toThrow(
      /invalid Ethereum address/,
    );
  });

  test("rejects the zero address", () => {
    expect(() => normalizeRecipients([addr(0)])).toThrow(/zero address/);
  });

  test("rejects case-insensitive duplicates", () => {
    const lower = addr(0xabcdef);
    const checksummed = getAddress(lower); // EIP-55 mixed case, same address
    expect(checksummed).not.toBe(lower);
    expect(() => normalizeRecipients([lower, checksummed])).toThrow(
      /duplicate address/,
    );
  });
});

describe("normalizeProvenance", () => {
  test("accepts a complete fixture and canonicalizes it", () => {
    const result = normalizeProvenance({
      ...provenance(),
      snapshotBlockHash: `0x${"AB".repeat(32)}`,
      sourceContracts: [SOURCE_CONTRACT.toLowerCase()],
    });
    expect(result.snapshotBlockHash).toBe(`0x${"ab".repeat(32)}`);
    expect(result.sourceContracts).toEqual([SOURCE_CONTRACT]);
  });

  test("rejects a non-positive chain ID", () => {
    expect(() => normalizeProvenance(provenance({ chainId: 0 }))).toThrow(
      /chainId must be positive/,
    );
    expect(() => normalizeProvenance(provenance({ chainId: -1 }))).toThrow(
      /chainId must be positive/,
    );
  });

  test("rejects a malformed or non-positive block number", () => {
    expect(() =>
      normalizeProvenance(provenance({ snapshotBlockNumber: "1e6" })),
    ).toThrow(/snapshotBlockNumber/);
    expect(() =>
      normalizeProvenance(provenance({ snapshotBlockNumber: "007" })),
    ).toThrow(/snapshotBlockNumber/);
    expect(() =>
      normalizeProvenance(provenance({ snapshotBlockNumber: "0" })),
    ).toThrow(/snapshotBlockNumber must be positive/);
  });

  test("requires a 32-byte block hash", () => {
    expect(() =>
      normalizeProvenance(
        provenance({ snapshotBlockHash: `0x${"1".repeat(62)}` }),
      ),
    ).toThrow(/snapshotBlockHash/);
  });

  test("requires at least one source contract", () => {
    expect(() =>
      normalizeProvenance(provenance({ sourceContracts: [] })),
    ).toThrow(/at least one source contract/);
  });

  test("rejects an invalid, zero, or duplicated source contract", () => {
    expect(() =>
      normalizeProvenance(
        provenance({ sourceContracts: ["0x123" as `0x${string}`] }),
      ),
    ).toThrow(/valid Ethereum address/);
    expect(() =>
      normalizeProvenance(
        provenance({ sourceContracts: [addr(0) as `0x${string}`] }),
      ),
    ).toThrow(/zero address/);
    expect(() =>
      normalizeProvenance(
        provenance({
          sourceContracts: [
            SOURCE_CONTRACT.toLowerCase() as `0x${string}`,
            SOURCE_CONTRACT,
          ],
        }),
      ),
    ).toThrow(/duplicates/);
  });

  test("rejects malformed SHA-256 checksums", () => {
    expect(() =>
      normalizeProvenance(provenance({ sourceDataChecksum: "a".repeat(64) })),
    ).toThrow(/sourceDataChecksum/);
    expect(() =>
      normalizeProvenance(
        provenance({ rulesetChecksum: `sha256:${"A".repeat(64)}` }),
      ),
    ).toThrow(/rulesetChecksum/);
  });

  test("rejects an empty ruleset identifier", () => {
    expect(() => normalizeProvenance(provenance({ rulesetId: "" }))).toThrow(
      /rulesetId must not be empty/,
    );
  });
});

describe("buildManifest", () => {
  test("requires provenance", () => {
    expect(() =>
      buildManifest([addr(1)], {
        batchSize: 1,
        provenance: undefined as unknown as RecipientProvenance,
      }),
    ).toThrow(/invalid recipient provenance/);
  });

  test("records the provenance verbatim and stamps the schema version", () => {
    const manifest = build([addr(1)], 1);
    expect(manifest.schemaVersion).toBe(MANIFEST_SCHEMA_VERSION);
    expect(manifest.provenance).toEqual(provenance());
  });

  test("rejects an empty recipient list", () => {
    expect(() => build([], 10)).toThrow(/recipient list is empty/);
  });

  test("splits into batches no larger than the operational batch size", () => {
    const recipients = Array.from({ length: 250 }, (_, i) => addr(i + 1));
    const manifest = build(recipients, 100);

    expect(manifest.batches.map((b) => b.recipientCount)).toEqual([
      100, 100, 50,
    ]);
    for (const batch of manifest.batches) {
      expect(batch.recipientCount).toBeLessThanOrEqual(100);
      expect(batch.recipientCount).toBeLessThanOrEqual(MAX_BATCH_SIZE);
    }
  });

  test("derives recipientCap and maximumSupply from 250 unique recipients", () => {
    const recipients = Array.from({ length: 250 }, (_, i) => addr(i + 1));
    const manifest = build(recipients, 100);

    expect(manifest.recipientCap).toBe("250");
    expect(manifest.maximumSupply).toBe(
      (250n * TOKEN_PER_RECIPIENT).toString(10),
    );
  });

  test("derives the cap from the deduplicated list, not the raw input length", () => {
    // Duplicates are rejected outright, so a caller cannot inflate the cap with repeats.
    expect(() => build([addr(1), addr(1)], 10)).toThrow(/duplicate address/);
  });

  test("no caller can request cap headroom: the API accepts no cap at all", () => {
    const recipients = Array.from({ length: 5 }, (_, i) => addr(i + 1));
    // BuildOptions has no recipientCap field, so headroom cannot be requested through the type at
    // all. Even smuggled in at runtime it is ignored: the cap is always the disclosed count.
    const smuggled = {
      batchSize: 2,
      provenance: provenance(),
      recipientCap: 1_000_000n,
    } as unknown as BuildOptions;
    const manifest = buildManifest(recipients, smuggled);
    expect(manifest.recipientCap).toBe("5");
    expect(manifest.maximumSupply).toBe(
      (5n * TOKEN_PER_RECIPIENT).toString(10),
    );
    expect(manifest).not.toHaveProperty("recipientCapHeadroom");
  });

  test("records cumulative counts and the remaining initial allocation after each batch", () => {
    const recipients = Array.from({ length: 250 }, (_, i) => addr(i + 1));
    const manifest = build(recipients, 100);

    expect(manifest.batches.map((b) => b.cumulativeRecipients)).toEqual([
      100, 200, 250,
    ]);
    expect(
      manifest.batches.map((b) => b.expectedRemainingInitialAllocationAfter),
    ).toEqual([
      (150n * TOKEN_PER_RECIPIENT).toString(10),
      (50n * TOKEN_PER_RECIPIENT).toString(10),
      "0",
    ]);
    expect(manifest.batches.map((b) => b.batchNumber)).toEqual([1, 2, 3]);
  });

  test("the final batch leaves zero remaining initial allocation", () => {
    for (const [count, batchSize] of [
      [250, 100],
      [1, 1],
      [200, 200],
      [7, 3],
    ] as const) {
      const recipients = Array.from({ length: count }, (_, i) => addr(i + 1));
      const manifest = build(recipients, batchSize);
      const last = manifest.batches[manifest.batches.length - 1];
      expect(last?.expectedRemainingInitialAllocationAfter).toBe("0");
      expect(last?.cumulativeRecipients).toBe(count);
    }
  });

  test("includes deterministic checksums and first/last addresses", () => {
    const recipients = Array.from({ length: 5 }, (_, i) => addr(i + 1));
    const first = build(recipients, 2);
    const second = build(recipients, 2);

    expect(first).toEqual(second); // fully deterministic
    expect(first.manifestChecksum).toMatch(/^sha256:[0-9a-f]{64}$/);
    expect(first.canonicalRecipientsChecksum).toMatch(/^sha256:[0-9a-f]{64}$/);
    for (const batch of first.batches) {
      expect(batch.batchChecksum).toMatch(/^sha256:[0-9a-f]{64}$/);
      expect(batch.firstAddress).toBe(batch.recipients[0] as `0x${string}`);
      expect(batch.lastAddress).toBe(
        batch.recipients[batch.recipients.length - 1] as `0x${string}`,
      );
    }
  });

  test("the canonical recipients checksum covers the normalized array, not the input order", () => {
    const forward = build([addr(1), addr(2), addr(3)], 5);
    const shuffled = build([addr(3), addr(1), addr(2)], 5);
    // Same canonical set, so the same canonical checksum. This is exactly why it cannot prove the
    // original source data was unchanged; provenance.sourceDataChecksum covers that.
    expect(shuffled.canonicalRecipientsChecksum).toBe(
      forward.canonicalRecipientsChecksum,
    );
  });

  test("the manifest checksum changes when provenance changes", () => {
    const recipients = [addr(1), addr(2)];
    const base = buildManifest(recipients, {
      batchSize: 2,
      provenance: provenance(),
    });
    const other = buildManifest(recipients, {
      batchSize: 2,
      provenance: provenance({ rulesetId: "fixture-ruleset-v2" }),
    });
    expect(other.manifestChecksum).not.toBe(base.manifestChecksum);
    // ... while the recipient array itself is untouched.
    expect(other.canonicalRecipientsChecksum).toBe(
      base.canonicalRecipientsChecksum,
    );
  });

  test("rejects an out-of-range batch size", () => {
    expect(() => build([addr(1)], 0)).toThrow(/batchSize/);
    expect(() => build([addr(1)], MAX_BATCH_SIZE + 1)).toThrow(/batchSize/);
  });

  test("does not mutate its input", () => {
    const recipients = [addr(3), addr(1), addr(2)];
    const copy = [...recipients];
    build(recipients, 2);
    expect(recipients).toEqual(copy);
  });
});

describe("serialization", () => {
  test("JSON round-trips the manifest structure", () => {
    const recipients = Array.from({ length: 3 }, (_, i) => addr(i + 1));
    const manifest = build(recipients, 2);
    const json = manifestToJson(manifest);
    expect(json.endsWith("\n")).toBe(true);
    expect(JSON.parse(json)).toEqual(manifest);
  });

  test("JSON carries the renamed v2 fields and none of the v1 names", () => {
    const manifest = build([addr(1)], 1);
    const parsed = JSON.parse(manifestToJson(manifest));

    expect(parsed).toHaveProperty("canonicalRecipientsChecksum");
    expect(parsed).toHaveProperty("provenance.sourceDataChecksum");
    expect(parsed.batches[0]).toHaveProperty(
      "expectedRemainingInitialAllocationAfter",
    );

    expect(parsed).not.toHaveProperty("inputChecksum");
    expect(parsed.batches[0]).not.toHaveProperty("expectedReserveAfter");
  });

  test("CSV lists one row per recipient with batch and position", () => {
    const recipients = Array.from({ length: 3 }, (_, i) => addr(i + 1));
    const manifest = build(recipients, 2);
    const csv = manifestToCsv(manifest);
    const lines = csv.trimEnd().split("\n");
    expect(lines[0]).toBe(
      "batch_number,position_in_batch,cumulative_index,address",
    );
    expect(lines).toHaveLength(1 + 3); // header + 3 recipients
    expect(lines[1]).toContain("1,1,1,");
    expect(lines[3]).toContain("2,1,3,");
  });
});
