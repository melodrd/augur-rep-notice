import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { getAddress } from "viem";

import {
  main,
  parseBatchSize,
  parseChainId,
  parseRecipientsInput,
} from "../src/cli.ts";
import { sha256 } from "../src/io.ts";
import {
  buildManifest,
  manifestToJson,
  MAX_BATCH_SIZE,
  type Provenance,
} from "../src/manifest.ts";

function addr(n: number): string {
  return `0x${n.toString(16).padStart(40, "0")}`;
}

/** Explicit fixture. Not a proposed REP snapshot, ruleset, or source contract. */
const PROVENANCE: Provenance = {
  sourceChainId: 1,
  snapshotBlockNumber: "21000000",
  snapshotBlockHash: `0x${"1".repeat(64)}`,
  sourceContracts: [getAddress(addr(0xabc123)) as `0x${string}`],
  sourceDataSha256: `sha256:${"a".repeat(64)}`,
  rulesetId: "fixture-ruleset-v1",
  rulesetSha256: `sha256:${"b".repeat(64)}`,
};

const TARGET_CHAIN_ID = 11155111;
const DEPLOYED_TOKEN = getAddress(addr(0xdeadbeef));
const COMMIT = "a".repeat(40);
const RUNTIME_HASH = `sha256:${"c".repeat(64)}`;

const temporaryDirectories: string[] = [];

async function tempDir(): Promise<string> {
  const dir = await mkdtemp(path.join(tmpdir(), "mrep2-ops-"));
  temporaryDirectories.push(dir);
  return dir;
}

async function manifestWorkspace(recipientCount: number) {
  const dir = await tempDir();
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

/** Write a valid manifest.json (+ its detached checksum) and return paths for the plan command. */
async function planWorkspace(recipientCount: number, batchSize = 100) {
  const dir = await tempDir();
  const manifestFile = path.join(dir, "manifest.json");
  const json = manifestToJson(
    buildManifest(
      Array.from({ length: recipientCount }, (_, i) => addr(i + 1)),
      PROVENANCE,
      batchSize,
    ),
  );
  await Bun.write(manifestFile, json);
  const checksumFile = path.join(dir, "manifest.json.sha256");
  await Bun.write(checksumFile, `${sha256(json)}\n`);
  return {
    dir,
    manifestFile,
    checksumFile,
    outputFile: path.join(dir, "plan.json"),
  };
}

function planArgs(manifestFile: string, outputFile: string): string[] {
  return [
    "plan",
    "--manifest",
    manifestFile,
    "--target-chain-id",
    String(TARGET_CHAIN_ID),
    "--token",
    DEPLOYED_TOKEN,
    "--source-commit",
    COMMIT,
    "--runtime-bytecode-sha256",
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

describe("argument parsing", () => {
  test("parseRecipientsInput accepts an array or a wrapped object", () => {
    expect(parseRecipientsInput([addr(1), addr(2)], "f")).toEqual([
      addr(1),
      addr(2),
    ]);
    expect(parseRecipientsInput({ recipients: [addr(1)] }, "f")).toEqual([
      addr(1),
    ]);
  });

  test("parseRecipientsInput rejects any other shape", () => {
    expect(() => parseRecipientsInput({ addresses: [addr(1)] }, "f")).toThrow(
      /expected a JSON array/,
    );
    expect(() => parseRecipientsInput("0x1", "f")).toThrow(
      /expected a JSON array/,
    );
  });

  test("parseBatchSize defaults to 100 and enforces the range", () => {
    expect(parseBatchSize(undefined)).toBe(100);
    expect(parseBatchSize("1")).toBe(1);
    expect(parseBatchSize(String(MAX_BATCH_SIZE))).toBe(MAX_BATCH_SIZE);
    expect(() => parseBatchSize("0")).toThrow(/--batch-size/);
    expect(() => parseBatchSize(String(MAX_BATCH_SIZE + 1))).toThrow(
      /--batch-size/,
    );
    expect(() => parseBatchSize("abc")).toThrow(/--batch-size/);
  });

  test("parseChainId accepts positive integers only", () => {
    expect(parseChainId("11155111")).toBe(11155111);
    expect(() => parseChainId("0")).toThrow(/--target-chain-id/);
    expect(() => parseChainId("1.5")).toThrow(/--target-chain-id/);
    expect(() => parseChainId("abc")).toThrow(/--target-chain-id/);
  });
});

describe("dispatcher", () => {
  test("--help exits successfully", async () => {
    expect(await main(["--help"])).toBe(0);
    expect(await main(["manifest", "--help"])).toBe(0);
    expect(await main(["plan", "--help"])).toBe(0);
  });

  test("rejects a missing or unknown subcommand", async () => {
    expect(await main([])).toBe(2);
    expect(await main(["frobnicate"])).toBe(2);
  });
});

describe("manifest subcommand", () => {
  test("writes manifest.json and a matching detached checksum", async () => {
    const { recipientsFile, provenanceFile, outDir } =
      await manifestWorkspace(250);

    const code = await main([
      "manifest",
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

    const jsonText = await Bun.file(path.join(outDir, "manifest.json")).text();
    const manifest = JSON.parse(jsonText);
    expect(manifest.version).toBe(1);
    expect(manifest.recipients).toHaveLength(250);
    expect(manifest.provenance).toEqual(PROVENANCE);

    // The detached checksum is the SHA-256 of the exact manifest.json bytes.
    const checksum = (
      await Bun.file(path.join(outDir, "manifest.json.sha256")).text()
    ).trim();
    expect(checksum).toBe(sha256(jsonText));
  });

  test("refuses to overwrite existing output unless --force", async () => {
    const { recipientsFile, provenanceFile, outDir } =
      await manifestWorkspace(5);
    const args = [
      "manifest",
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
    expect(await Bun.file(path.join(outDir, "manifest.json")).text()).toBe(
      first,
    );

    expect(await main([...args, "--force"])).toBe(0);
  });

  test("fails on an empty recipient list and writes nothing", async () => {
    const { recipientsFile, provenanceFile, outDir } =
      await manifestWorkspace(0);
    await expect(
      main([
        "manifest",
        "--recipients",
        recipientsFile,
        "--provenance",
        provenanceFile,
        "--out-dir",
        outDir,
      ]),
    ).rejects.toThrow(/recipient list is empty/);
    expect(await Bun.file(path.join(outDir, "manifest.json")).exists()).toBe(
      false,
    );
  });

  test("reports a missing input file", async () => {
    const { provenanceFile, outDir } = await manifestWorkspace(3);
    await expect(
      main([
        "manifest",
        "--recipients",
        path.join(outDir, "absent.json"),
        "--provenance",
        provenanceFile,
        "--out-dir",
        outDir,
      ]),
    ).rejects.toThrow(/no such file/);
  });

  test("rejects malformed JSON input", async () => {
    const { dir, provenanceFile, outDir } = await manifestWorkspace(3);
    const badFile = path.join(dir, "bad.json");
    await Bun.write(badFile, "{ not valid json");
    await expect(
      main([
        "manifest",
        "--recipients",
        badFile,
        "--provenance",
        provenanceFile,
        "--out-dir",
        outDir,
      ]),
    ).rejects.toThrow(/invalid JSON/);
  });

  test("returns a usage error when a required option is missing", async () => {
    const { recipientsFile } = await manifestWorkspace(3);
    expect(await main(["manifest", "--recipients", recipientsFile])).toBe(2);
  });
});

describe("plan subcommand", () => {
  test("writes a deterministic plan and a matching detached checksum", async () => {
    const { manifestFile, outputFile } = await planWorkspace(5, 2);

    expect(await main(planArgs(manifestFile, outputFile))).toBe(0);

    const jsonText = await Bun.file(outputFile).text();
    const plan = JSON.parse(jsonText);
    expect(plan.version).toBe(1);
    expect(plan.targetChainId).toBe(TARGET_CHAIN_ID);
    expect(plan.token).toBe(DEPLOYED_TOKEN);
    expect(
      plan.batches.flatMap((b: { recipients: string[] }) => b.recipients),
    ).toHaveLength(5);
    // manifestSha256 binds the plan to the exact manifest bytes.
    expect(plan.manifestSha256).toBe(
      sha256(await Bun.file(manifestFile).text()),
    );

    const checksum = (await Bun.file(`${outputFile}.sha256`).text()).trim();
    expect(checksum).toBe(sha256(jsonText));

    // Determinism: a second run over the same manifest produces byte-identical plan JSON.
    const secondOutput = path.join(path.dirname(outputFile), "plan-2.json");
    expect(await main(planArgs(manifestFile, secondOutput))).toBe(0);
    expect(await Bun.file(secondOutput).text()).toBe(jsonText);
  });

  test("verifies a provided manifest checksum and rejects a mismatch", async () => {
    const { manifestFile, checksumFile, outputFile } = await planWorkspace(3);

    // Correct sidecar: accepted.
    expect(
      await main([
        ...planArgs(manifestFile, outputFile),
        "--manifest-sha256",
        checksumFile,
      ]),
    ).toBe(0);

    // Wrong sidecar: rejected before any plan is written.
    const wrongFile = path.join(path.dirname(manifestFile), "wrong.sha256");
    await Bun.write(wrongFile, `sha256:${"0".repeat(64)}\n`);
    const out2 = path.join(path.dirname(manifestFile), "plan-2.json");
    await expect(
      main([...planArgs(manifestFile, out2), "--manifest-sha256", wrongFile]),
    ).rejects.toThrow(/manifest checksum mismatch/);
    expect(await Bun.file(out2).exists()).toBe(false);
  });

  test("refuses to overwrite existing output unless --force", async () => {
    const { manifestFile, outputFile } = await planWorkspace(3);
    const args = planArgs(manifestFile, outputFile);

    expect(await main(args)).toBe(0);
    const first = await Bun.file(outputFile).text();

    await expect(main(args)).rejects.toThrow(/refusing to overwrite/);
    expect(await Bun.file(outputFile).text()).toBe(first);

    expect(await main([...args, "--force"])).toBe(0);
  });

  test("rejects a manifest that does not parse and writes nothing", async () => {
    const { dir } = await planWorkspace(3);
    const badManifest = path.join(dir, "bad-manifest.json");
    await Bun.write(badManifest, JSON.stringify({ version: 2 }));
    const output = path.join(dir, "plan.json");
    await expect(main(planArgs(badManifest, output))).rejects.toThrow(
      /unsupported manifest version/,
    );
    expect(await Bun.file(output).exists()).toBe(false);
  });

  test("rejects a missing manifest file", async () => {
    const { dir, outputFile } = await planWorkspace(3);
    await expect(
      main(planArgs(path.join(dir, "absent.json"), outputFile)),
    ).rejects.toThrow(/no such file/);
  });

  test("returns a usage error when a required option is missing", async () => {
    const { manifestFile } = await planWorkspace(3);
    expect(await main(["plan", "--manifest", manifestFile])).toBe(2);
  });
});
