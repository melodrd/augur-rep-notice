import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { getAddress } from "viem";

import { main, parseBatchSize, parseRecipientsInput } from "../src/cli.ts";
import { MAX_BATCH_SIZE, type RecipientProvenance } from "../src/manifest.ts";

function addr(n: number): string {
  return `0x${n.toString(16).padStart(40, "0")}`;
}

/** Explicit fixture. Not a proposed REP snapshot, ruleset, or source contract. */
const PROVENANCE: RecipientProvenance = {
  chainId: 1,
  snapshotBlockNumber: "21000000",
  snapshotBlockHash: `0x${"1".repeat(64)}`,
  sourceContracts: [getAddress(addr(0xabc123)) as `0x${string}`],
  sourceDataChecksum: `sha256:${"a".repeat(64)}`,
  rulesetId: "fixture-ruleset-v1",
  rulesetChecksum: `sha256:${"b".repeat(64)}`,
};

const temporaryDirectories: string[] = [];

async function workspace(recipientCount: number) {
  const dir = await mkdtemp(path.join(tmpdir(), "mrep2-cli-"));
  temporaryDirectories.push(dir);

  const recipientsFile = path.join(dir, "recipients.json");
  const provenanceFile = path.join(dir, "provenance.json");
  const outDir = path.join(dir, "out");

  await Bun.write(
    recipientsFile,
    JSON.stringify(
      Array.from({ length: recipientCount }, (_, i) => addr(i + 1)),
    ),
  );
  await Bun.write(provenanceFile, JSON.stringify(PROVENANCE));

  return { dir, recipientsFile, provenanceFile, outDir };
}

afterEach(async () => {
  await Promise.all(
    temporaryDirectories
      .splice(0)
      .map((dir) => rm(dir, { recursive: true, force: true })),
  );
});

describe("parseRecipientsInput", () => {
  test("accepts a bare array", () => {
    expect(parseRecipientsInput([addr(1), addr(2)], "f")).toEqual([
      addr(1),
      addr(2),
    ]);
  });

  test("accepts a wrapped object", () => {
    expect(parseRecipientsInput({ recipients: [addr(1)] }, "f")).toEqual([
      addr(1),
    ]);
  });

  test("rejects any other shape without coercing", () => {
    expect(() => parseRecipientsInput({ addresses: [addr(1)] }, "f")).toThrow(
      /expected a JSON array/,
    );
    expect(() => parseRecipientsInput("0x1", "f")).toThrow(
      /expected a JSON array/,
    );
    expect(() => parseRecipientsInput([1, 2], "f")).toThrow(/not a string/);
  });
});

describe("parseBatchSize", () => {
  test("defaults to 100 and accepts the valid range", () => {
    expect(parseBatchSize(undefined)).toBe(100);
    expect(parseBatchSize("1")).toBe(1);
    expect(parseBatchSize(String(MAX_BATCH_SIZE))).toBe(MAX_BATCH_SIZE);
  });

  test("rejects an out-of-range or malformed size", () => {
    expect(() => parseBatchSize("0")).toThrow(/--batch-size/);
    expect(() => parseBatchSize(String(MAX_BATCH_SIZE + 1))).toThrow(
      /--batch-size/,
    );
    expect(() => parseBatchSize("abc")).toThrow(/--batch-size/);
  });
});

describe("main", () => {
  test("writes a manifest with the derived cap as JSON and CSV", async () => {
    const { recipientsFile, provenanceFile, outDir } = await workspace(250);

    const code = await main([
      "--recipients",
      recipientsFile,
      "--provenance",
      provenanceFile,
      "--out-dir",
      outDir,
      "--batch-size",
      "100",
    ]);
    expect(code).toBe(0);

    const manifest = JSON.parse(
      await Bun.file(path.join(outDir, "manifest.json")).text(),
    );
    expect(manifest.recipientCap).toBe("250");
    expect(manifest.schemaVersion).toBe(2);
    expect(manifest.provenance).toEqual(PROVENANCE);
    expect(manifest.batches).toHaveLength(3);

    const csv = await Bun.file(path.join(outDir, "manifest.csv")).text();
    expect(csv.split("\n")[0]).toBe(
      "batch_number,position_in_batch,cumulative_index,address",
    );
    expect(csv.trimEnd().split("\n")).toHaveLength(1 + 250);
  });

  test("refuses to overwrite existing output unless --force", async () => {
    const { recipientsFile, provenanceFile, outDir } = await workspace(5);
    const args = [
      "--recipients",
      recipientsFile,
      "--provenance",
      provenanceFile,
      "--out-dir",
      outDir,
    ];

    expect(await main(args)).toBe(0);
    const first = await Bun.file(path.join(outDir, "manifest.json")).text();

    await expect(main(args)).rejects.toThrow(/refusing to overwrite/);
    // The refused run left the original output untouched.
    expect(await Bun.file(path.join(outDir, "manifest.json")).text()).toBe(
      first,
    );

    expect(await main([...args, "--force"])).toBe(0);
  });

  test("fails on an empty recipient list", async () => {
    const { recipientsFile, provenanceFile, outDir } = await workspace(0);
    await expect(
      main([
        "--recipients",
        recipientsFile,
        "--provenance",
        provenanceFile,
        "--out-dir",
        outDir,
      ]),
    ).rejects.toThrow(/recipient list is empty/);
  });

  test("fails on missing provenance rather than defaulting it", async () => {
    const { dir, recipientsFile, outDir } = await workspace(3);
    const emptyProvenance = path.join(dir, "empty.json");
    await Bun.write(emptyProvenance, JSON.stringify({}));

    await expect(
      main([
        "--recipients",
        recipientsFile,
        "--provenance",
        emptyProvenance,
        "--out-dir",
        outDir,
      ]),
    ).rejects.toThrow(/invalid recipient provenance/);
  });

  test("reports a missing input file", async () => {
    const { provenanceFile, outDir } = await workspace(3);
    await expect(
      main([
        "--recipients",
        path.join(outDir, "absent.json"),
        "--provenance",
        provenanceFile,
        "--out-dir",
        outDir,
      ]),
    ).rejects.toThrow(/no such file/);
  });

  test("returns a usage error when a required option is missing", async () => {
    const { recipientsFile } = await workspace(3);
    expect(await main(["--recipients", recipientsFile])).toBe(2);
  });

  test("--help exits successfully", async () => {
    expect(await main(["--help"])).toBe(0);
  });
});
