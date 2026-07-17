import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { getAddress } from "viem";

import {
  buildManifest,
  manifestToJson,
  type RecipientProvenance,
} from "../src/manifest.ts";
import { main, parseChainId } from "../src/plan-cli.ts";

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

const CHAIN_ID = 1;
const DEPLOYED_TOKEN = getAddress(addr(0xdeadbeef));
const COMMIT = "a".repeat(40);
const RUNTIME_HASH = `sha256:${"c".repeat(64)}`;

const temporaryDirectories: string[] = [];

async function workspace(recipientCount: number, batchSize = 100) {
  const dir = await mkdtemp(path.join(tmpdir(), "mrep2-plan-cli-"));
  temporaryDirectories.push(dir);

  const manifestFile = path.join(dir, "manifest.json");
  const manifest = buildManifest(
    Array.from({ length: recipientCount }, (_, i) => addr(i + 1)),
    { batchSize, provenance: PROVENANCE },
  );
  await Bun.write(manifestFile, manifestToJson(manifest));

  const outputFile = path.join(dir, "plan.json");
  return { dir, manifestFile, outputFile };
}

function planArgs(manifestFile: string, outputFile: string): string[] {
  return [
    "--manifest",
    manifestFile,
    "--chain-id",
    String(CHAIN_ID),
    "--token",
    DEPLOYED_TOKEN,
    "--source-commit",
    COMMIT,
    "--runtime-bytecode-hash",
    RUNTIME_HASH,
    "--output",
    outputFile,
  ];
}

afterEach(async () => {
  await Promise.all(
    temporaryDirectories
      .splice(0)
      .map((dir) => rm(dir, { recursive: true, force: true })),
  );
});

describe("parseChainId", () => {
  test("accepts a positive integer", () => {
    expect(parseChainId("1")).toBe(1);
    expect(parseChainId("11155111")).toBe(11155111);
  });

  test("rejects zero, negative, non-integer, or non-numeric values", () => {
    expect(() => parseChainId("0")).toThrow(/--chain-id/);
    expect(() => parseChainId("-1")).toThrow(/--chain-id/);
    expect(() => parseChainId("1.5")).toThrow(/--chain-id/);
    expect(() => parseChainId("abc")).toThrow(/--chain-id/);
  });
});

describe("main", () => {
  test("writes a deterministic distribution plan", async () => {
    const { manifestFile, outputFile } = await workspace(5, 2);

    const code = await main(planArgs(manifestFile, outputFile));
    expect(code).toBe(0);

    const plan = JSON.parse(await Bun.file(outputFile).text());
    expect(plan.chainId).toBe(CHAIN_ID);
    expect(plan.deployedToken).toBe(DEPLOYED_TOKEN);
    expect(plan.totalRecipients).toBe(5);
    expect(plan.totalBatches).toBe(3);
    expect(plan.candidateSourceCommit).toBe(COMMIT);
    expect(plan.runtimeBytecodeHash).toBe(RUNTIME_HASH);

    // Determinism: the same manifest and arguments produce byte-identical plan JSON.
    const secondOutput = path.join(path.dirname(outputFile), "plan-2.json");
    expect(await main(planArgs(manifestFile, secondOutput))).toBe(0);
    expect(await Bun.file(secondOutput).text()).toBe(
      await Bun.file(outputFile).text(),
    );
  });

  test("refuses to overwrite existing output unless --force", async () => {
    const { manifestFile, outputFile } = await workspace(3);
    const runArgs = planArgs(manifestFile, outputFile);

    expect(await main(runArgs)).toBe(0);
    const first = await Bun.file(outputFile).text();

    await expect(main(runArgs)).rejects.toThrow(/refusing to overwrite/);
    // The refused run left the original output untouched.
    expect(await Bun.file(outputFile).text()).toBe(first);

    expect(await main([...runArgs, "--force"])).toBe(0);
  });

  test("rejects a manifest with a tampered checksum", async () => {
    const { manifestFile, outputFile } = await workspace(3);
    const manifest = (await Bun.file(manifestFile).json()) as Record<
      string,
      unknown
    >;
    manifest.manifestChecksum = `sha256:${"0".repeat(64)}`;
    await Bun.write(manifestFile, JSON.stringify(manifest));

    await expect(main(planArgs(manifestFile, outputFile))).rejects.toThrow(
      /manifestChecksum does not match/,
    );
  });

  test("rejects an unsupported manifest schema version", async () => {
    const { manifestFile, outputFile } = await workspace(3);
    const manifest = (await Bun.file(manifestFile).json()) as Record<
      string,
      unknown
    >;
    manifest.schemaVersion = 1;
    await Bun.write(manifestFile, JSON.stringify(manifest));

    await expect(main(planArgs(manifestFile, outputFile))).rejects.toThrow(
      /unsupported manifest schema version/,
    );
  });

  test("rejects a missing manifest file", async () => {
    const { dir, outputFile } = await workspace(3);
    await expect(
      main(planArgs(path.join(dir, "absent.json"), outputFile)),
    ).rejects.toThrow(/no such file/);
  });

  test("rejects an invalid chain id", async () => {
    const { manifestFile, outputFile } = await workspace(3);
    await expect(
      main([
        "--manifest",
        manifestFile,
        "--chain-id",
        "0",
        "--token",
        DEPLOYED_TOKEN,
        "--source-commit",
        COMMIT,
        "--runtime-bytecode-hash",
        RUNTIME_HASH,
        "--output",
        outputFile,
      ]),
    ).rejects.toThrow(/--chain-id/);
  });

  test("rejects a malformed deployed token address", async () => {
    const { manifestFile, outputFile } = await workspace(3);
    await expect(
      main([
        "--manifest",
        manifestFile,
        "--chain-id",
        String(CHAIN_ID),
        "--token",
        "0x123",
        "--source-commit",
        COMMIT,
        "--runtime-bytecode-hash",
        RUNTIME_HASH,
        "--output",
        outputFile,
      ]),
    ).rejects.toThrow(/valid Ethereum address/);
  });

  test("returns a usage error when a required option is missing", async () => {
    const { manifestFile } = await workspace(3);
    expect(await main(["--manifest", manifestFile])).toBe(2);
  });

  test("--help exits successfully", async () => {
    expect(await main(["--help"])).toBe(0);
  });
});
