import { describe, expect, test } from "bun:test";
import { getAddress } from "viem";
import {
  buildManifest,
  type Manifest,
  MANIFEST_VERSION,
  MAX_BATCH_SIZE,
  manifestToJson,
  maximumSupply,
  normalizeRecipients,
  parseManifest,
  parseProvenance,
  type Provenance,
  recipientCap,
  splitBatches,
  TOKEN_PER_RECIPIENT,
} from "../src/manifest.ts";

function addr(n: number): string {
  return `0x${n.toString(16).padStart(40, "0")}`;
}

const CHECKSUM_A = `sha256:${"a".repeat(64)}`;
const CHECKSUM_B = `sha256:${"b".repeat(64)}`;

/** Stand-in for a reviewed source contract. Not a proposed REP or REPv2 address. */
const SOURCE_CONTRACT = getAddress(addr(0xabc123)) as `0x${string}`;

/** Explicit fixture. Provenance is never invented by the tooling; these are stand-in values. */
function provenance(overrides: Partial<Provenance> = {}): Provenance {
  return {
    sourceChainId: 1,
    snapshotBlockNumber: "21000000",
    snapshotBlockHash: `0x${"1".repeat(64)}`,
    sourceContracts: [SOURCE_CONTRACT],
    sourceDataSha256: CHECKSUM_A,
    rulesetId: "fixture-ruleset-v1",
    rulesetSha256: CHECKSUM_B,
    ...overrides,
  };
}

function build(recipients: readonly string[], batchSize: number): Manifest {
  return buildManifest(recipients, provenance(), batchSize);
}

describe("normalizeRecipients", () => {
  test("sorts ascending by lowercase hex and checksums output", () => {
    const result = normalizeRecipients([addr(3), addr(1), addr(2)]);
    expect(result.map((a) => a.toLowerCase())).toEqual([
      addr(1),
      addr(2),
      addr(3),
    ]);
    // Checksummed, human-facing form.
    expect(result).toEqual([
      getAddress(addr(1)),
      getAddress(addr(2)),
      getAddress(addr(3)),
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

describe("parseProvenance", () => {
  test("accepts a complete fixture and canonicalizes it", () => {
    const result = parseProvenance({
      ...provenance(),
      snapshotBlockHash: `0x${"AB".repeat(32)}`,
      sourceContracts: [SOURCE_CONTRACT.toLowerCase()],
    });
    expect(result.snapshotBlockHash).toBe(`0x${"ab".repeat(32)}`);
    expect(result.sourceContracts).toEqual([SOURCE_CONTRACT]);
  });

  test("rejects a non-object", () => {
    expect(() => parseProvenance(undefined)).toThrow(
      /invalid recipient provenance/,
    );
    expect(() => parseProvenance([])).toThrow(/invalid recipient provenance/);
  });

  test("rejects a non-positive source chain ID", () => {
    expect(() => parseProvenance(provenance({ sourceChainId: 0 }))).toThrow(
      /sourceChainId must be a positive integer/,
    );
    expect(() => parseProvenance(provenance({ sourceChainId: -1 }))).toThrow(
      /sourceChainId must be a positive integer/,
    );
  });

  test("rejects a malformed or non-positive block number", () => {
    expect(() =>
      parseProvenance(provenance({ snapshotBlockNumber: "1e6" })),
    ).toThrow(/snapshotBlockNumber/);
    expect(() =>
      parseProvenance(provenance({ snapshotBlockNumber: "007" })),
    ).toThrow(/snapshotBlockNumber/);
    expect(() =>
      parseProvenance(provenance({ snapshotBlockNumber: "0" })),
    ).toThrow(/snapshotBlockNumber/);
  });

  test("requires a 32-byte block hash", () => {
    expect(() =>
      parseProvenance(provenance({ snapshotBlockHash: `0x${"1".repeat(62)}` })),
    ).toThrow(/snapshotBlockHash/);
  });

  test("requires at least one source contract", () => {
    expect(() => parseProvenance(provenance({ sourceContracts: [] }))).toThrow(
      /sourceContracts must be a non-empty array/,
    );
  });

  test("rejects an invalid, zero, or duplicated source contract", () => {
    expect(() =>
      parseProvenance(
        provenance({ sourceContracts: ["0x123" as `0x${string}`] }),
      ),
    ).toThrow(/valid Ethereum address/);
    expect(() =>
      parseProvenance(
        provenance({ sourceContracts: [addr(0) as `0x${string}`] }),
      ),
    ).toThrow(/zero address/);
    expect(() =>
      parseProvenance(
        provenance({
          sourceContracts: [
            SOURCE_CONTRACT.toLowerCase() as `0x${string}`,
            SOURCE_CONTRACT,
          ],
        }),
      ),
    ).toThrow(/duplicate/);
  });

  test("rejects malformed SHA-256 checksums", () => {
    expect(() =>
      parseProvenance(provenance({ sourceDataSha256: "a".repeat(64) })),
    ).toThrow(/sourceDataSha256/);
    expect(() =>
      parseProvenance(
        provenance({ rulesetSha256: `sha256:${"A".repeat(64)}` }),
      ),
    ).toThrow(/rulesetSha256/);
  });

  test("rejects an empty ruleset identifier", () => {
    expect(() => parseProvenance(provenance({ rulesetId: "" }))).toThrow(
      /rulesetId must not be empty/,
    );
  });
});

describe("buildManifest", () => {
  test("records provenance verbatim and stamps the version", () => {
    const manifest = build([addr(1)], 1);
    expect(manifest.version).toBe(MANIFEST_VERSION);
    expect(manifest.provenance).toEqual(provenance());
  });

  test("rejects invalid provenance", () => {
    expect(() => buildManifest([addr(1)], undefined, 1)).toThrow(
      /invalid recipient provenance/,
    );
  });

  test("rejects an empty recipient list", () => {
    expect(() => build([], 10)).toThrow(/recipient list is empty/);
  });

  test("rejects an out-of-range batch size", () => {
    expect(() => build([addr(1)], 0)).toThrow(/batchSize/);
    expect(() => build([addr(1)], MAX_BATCH_SIZE + 1)).toThrow(/batchSize/);
  });

  test("derives cap and maximum supply from the unique recipient count", () => {
    const manifest = build(
      Array.from({ length: 250 }, (_, i) => addr(i + 1)),
      100,
    );
    expect(recipientCap(manifest)).toBe(250n);
    expect(maximumSupply(manifest)).toBe(250n * TOKEN_PER_RECIPIENT);
  });

  test("is deterministic", () => {
    const recipients = Array.from({ length: 5 }, (_, i) => addr(i + 1));
    expect(build(recipients, 2)).toEqual(build(recipients, 2));
  });

  test("does not mutate its input", () => {
    const recipients = [addr(3), addr(1), addr(2)];
    const copy = [...recipients];
    build(recipients, 2);
    expect(recipients).toEqual(copy);
  });
});

describe("splitBatches", () => {
  test("splits into deterministic batches no larger than the batch size", () => {
    const manifest = build(
      Array.from({ length: 250 }, (_, i) => addr(i + 1)),
      100,
    );
    const batches = splitBatches(manifest);
    expect(batches.map((b) => b.number)).toEqual([1, 2, 3]);
    expect(batches.map((b) => b.recipients.length)).toEqual([100, 100, 50]);
    for (const batch of batches) {
      expect(batch.recipients.length).toBeLessThanOrEqual(manifest.batchSize);
    }
    // Concatenation reproduces the canonical order exactly.
    expect(batches.flatMap((b) => b.recipients)).toEqual(manifest.recipients);
  });
});

describe("serialization", () => {
  test("JSON round-trips the lean structure and stores no derived fields", () => {
    const manifest = build([addr(1), addr(2), addr(3)], 2);
    const json = manifestToJson(manifest);
    expect(json.endsWith("\n")).toBe(true);

    const parsed = JSON.parse(json);
    expect(parsed).toEqual(manifest);
    expect(Object.keys(parsed)).toEqual([
      "version",
      "provenance",
      "batchSize",
      "recipients",
    ]);
    for (const derived of [
      "recipientCap",
      "maximumSupply",
      "tokenPerRecipient",
      "canonicalSortRule",
      "canonicalRecipientsChecksum",
      "manifestChecksum",
      "batches",
      "schemaVersion",
    ]) {
      expect(parsed).not.toHaveProperty(derived);
    }
  });
});

describe("parseManifest", () => {
  /** Round-trips a built manifest through JSON, exactly as loading it from a file would. */
  function serialize(manifest: Manifest): Record<string, unknown> {
    return JSON.parse(JSON.stringify(manifest));
  }

  test("accepts a valid serialized manifest and returns it normalized", () => {
    const manifest = build(
      Array.from({ length: 5 }, (_, i) => addr(i + 1)),
      2,
    );
    expect(parseManifest(serialize(manifest))).toEqual(manifest);
  });

  test("rejects a non-object", () => {
    expect(() => parseManifest(null)).toThrow(/manifest must be a JSON object/);
    expect(() => parseManifest([])).toThrow(/manifest must be a JSON object/);
  });

  test("rejects an unsupported version", () => {
    const tampered = serialize(build([addr(1)], 1));
    tampered.version = 2;
    expect(() => parseManifest(tampered)).toThrow(
      /unsupported manifest version/,
    );
  });

  test("rejects invalid provenance", () => {
    const tampered = serialize(build([addr(1)], 1));
    (tampered.provenance as Record<string, unknown>).sourceChainId = 0;
    expect(() => parseManifest(tampered)).toThrow(
      /sourceChainId must be a positive integer/,
    );
  });

  test("rejects an out-of-range batch size", () => {
    const tampered = serialize(build([addr(1)], 1));
    tampered.batchSize = 0;
    expect(() => parseManifest(tampered)).toThrow(/batchSize/);
  });

  test("rejects an empty recipient list", () => {
    const tampered = serialize(build([addr(1)], 1));
    tampered.recipients = [];
    expect(() => parseManifest(tampered)).toThrow(
      /recipients must not be empty/,
    );
  });

  test("rejects a malformed recipient", () => {
    const tampered = serialize(build([addr(1), addr(2), addr(3)], 5));
    (tampered.recipients as string[])[1] = "0xnotanaddress";
    expect(() => parseManifest(tampered)).toThrow(
      /not a valid Ethereum address/,
    );
  });

  test("rejects a zero-address recipient", () => {
    const tampered = serialize(build([addr(1), addr(2), addr(3)], 5));
    (tampered.recipients as string[])[1] = addr(0);
    expect(() => parseManifest(tampered)).toThrow(/zero address/);
  });

  test("rejects a recipient not in canonical EIP-55 checksummed form", () => {
    // addr(1) and addr(0xffffff) bracket addr(0xabcdef), so the mixed-case recipient stays at
    // index 1, a middle position that keeps the list otherwise sorted.
    const tampered = serialize(
      build([addr(1), addr(0xabcdef), addr(0xffffff)], 5),
    );
    const recipients = tampered.recipients as string[];
    const lowered = (recipients[1] as string).toLowerCase();
    expect(lowered).not.toBe(recipients[1]);
    recipients[1] = lowered;
    expect(() => parseManifest(tampered)).toThrow(
      /canonical EIP-55 checksummed form/,
    );
  });

  test("rejects an unsorted recipient list", () => {
    const tampered = serialize(build([addr(1), addr(2), addr(3)], 5));
    const recipients = tampered.recipients as string[];
    [recipients[0], recipients[1]] = [
      recipients[1] as string,
      recipients[0] as string,
    ];
    expect(() => parseManifest(tampered)).toThrow(/not sorted ascending/);
  });

  test("rejects a duplicate recipient", () => {
    const tampered = serialize(build([addr(1), addr(2), addr(3)], 5));
    const recipients = tampered.recipients as string[];
    recipients[1] = recipients[0] as string;
    expect(() => parseManifest(tampered)).toThrow(/duplicate recipient/);
  });
});
