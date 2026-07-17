import { describe, expect, test } from "bun:test";
import { getAddress } from "viem";
import {
  buildManifest,
  MAX_BATCH_SIZE,
  manifestToCsv,
  manifestToJson,
  normalizeRecipients,
  TOKEN_PER_RECIPIENT,
} from "../src/manifest.ts";

function addr(n: number): string {
  return `0x${n.toString(16).padStart(40, "0")}`;
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

describe("buildManifest", () => {
  test("splits into batches no larger than the operational batch size", () => {
    const recipients = Array.from({ length: 250 }, (_, i) => addr(i + 1));
    const manifest = buildManifest(recipients, {
      recipientCap: 250n,
      batchSize: 100,
    });

    expect(manifest.totalRecipients).toBe(250);
    expect(manifest.batches.map((b) => b.recipientCount)).toEqual([
      100, 100, 50,
    ]);
    for (const batch of manifest.batches) {
      expect(batch.recipientCount).toBeLessThanOrEqual(100);
      expect(batch.recipientCount).toBeLessThanOrEqual(MAX_BATCH_SIZE);
    }
  });

  test("records cumulative counts and expected reserve after each batch", () => {
    const recipients = Array.from({ length: 250 }, (_, i) => addr(i + 1));
    const manifest = buildManifest(recipients, {
      recipientCap: 300n,
      batchSize: 100,
    });

    const maximumSupply = 300n * TOKEN_PER_RECIPIENT;
    expect(manifest.maximumSupply).toBe(maximumSupply.toString(10));

    expect(manifest.batches.map((b) => b.cumulativeRecipients)).toEqual([
      100, 200, 250,
    ]);
    expect(manifest.batches.map((b) => b.expectedReserveAfter)).toEqual([
      (maximumSupply - 100n * TOKEN_PER_RECIPIENT).toString(10),
      (maximumSupply - 200n * TOKEN_PER_RECIPIENT).toString(10),
      (maximumSupply - 250n * TOKEN_PER_RECIPIENT).toString(10),
    ]);
    expect(manifest.batches.map((b) => b.batchNumber)).toEqual([1, 2, 3]);
  });

  test("includes deterministic checksums and first/last addresses", () => {
    const recipients = Array.from({ length: 5 }, (_, i) => addr(i + 1));
    const first = buildManifest(recipients, {
      recipientCap: 10n,
      batchSize: 2,
    });
    const second = buildManifest(recipients, {
      recipientCap: 10n,
      batchSize: 2,
    });

    expect(first).toEqual(second); // fully deterministic
    expect(first.manifestChecksum).toMatch(/^sha256:[0-9a-f]{64}$/);
    expect(first.inputChecksum).toMatch(/^sha256:[0-9a-f]{64}$/);
    for (const batch of first.batches) {
      expect(batch.batchChecksum).toMatch(/^sha256:[0-9a-f]{64}$/);
      expect(batch.firstAddress).toBe(batch.recipients[0] as `0x${string}`);
      expect(batch.lastAddress).toBe(
        batch.recipients[batch.recipients.length - 1] as `0x${string}`,
      );
    }
  });

  test("refuses to generate more recipients than the cap", () => {
    const recipients = Array.from({ length: 11 }, (_, i) => addr(i + 1));
    expect(() =>
      buildManifest(recipients, { recipientCap: 10n, batchSize: 5 }),
    ).toThrow(/exceeds recipientCap/);
  });

  test("rejects an out-of-range batch size", () => {
    expect(() =>
      buildManifest([addr(1)], { recipientCap: 10n, batchSize: 0 }),
    ).toThrow(/batchSize/);
    expect(() =>
      buildManifest([addr(1)], {
        recipientCap: 10n,
        batchSize: MAX_BATCH_SIZE + 1,
      }),
    ).toThrow(/batchSize/);
  });

  test("rejects a non-positive recipient cap", () => {
    expect(() =>
      buildManifest([addr(1)], { recipientCap: 0n, batchSize: 5 }),
    ).toThrow(/recipientCap/);
  });
});

describe("serialization", () => {
  test("JSON round-trips the manifest structure", () => {
    const recipients = Array.from({ length: 3 }, (_, i) => addr(i + 1));
    const manifest = buildManifest(recipients, {
      recipientCap: 10n,
      batchSize: 2,
    });
    const json = manifestToJson(manifest);
    expect(json.endsWith("\n")).toBe(true);
    expect(JSON.parse(json)).toEqual(manifest);
  });

  test("CSV lists one row per recipient with batch and position", () => {
    const recipients = Array.from({ length: 3 }, (_, i) => addr(i + 1));
    const manifest = buildManifest(recipients, {
      recipientCap: 10n,
      batchSize: 2,
    });
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
