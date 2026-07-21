// Offline CHECKAUGUR recipient tooling. One entry point, two subcommands:
//
//   bun run ops -- manifest \
//     --recipients ../data/snapshots/approved-recipients.json \
//     --provenance ../data/snapshots/approved-provenance.json \
//     --batch-size 100 \
//     --out-dir ../data/batches/candidate-1
//
//   bun run ops -- plan \
//     --manifest ../data/batches/candidate-1/manifest.json \
//     --manifest-sha256 ../data/batches/candidate-1/manifest.json.sha256 \
//     --target-chain-id 11155111 \
//     --token 0xDeployedTokenAddress... \
//     --source-commit <40-hex git commit SHA> \
//     --runtime-bytecode-sha256 sha256:<64 lowercase hex> \
//     --output ../data/plans/candidate-1/plan.json
//
// Both are offline: no network, no signing, no deployment, and no key or secret is ever read.
// Both refuse to overwrite existing output unless --force is passed.

import { parseArgs } from "node:util";
import path from "node:path";

import {
  buildDistributionPlan,
  type DistributionPlan,
  distributionPlanToJson,
} from "./distribution-plan.ts";
import {
  missingOptions,
  readJsonFile,
  readTextFile,
  sha256,
  writeFiles,
} from "./io.ts";
import {
  buildManifest,
  type Manifest,
  manifestToJson,
  MAX_BATCH_SIZE,
  maximumSupply,
  parseManifest,
  recipientCap,
  splitBatches,
} from "./manifest.ts";

const TOP_USAGE = `Usage:
  bun run ops -- manifest --recipients <f> --provenance <f> --out-dir <d> [options]
  bun run ops -- plan --manifest <f> --target-chain-id <n> --token <addr> \\
    --source-commit <sha> --runtime-bytecode-sha256 <sha256:...> --output <f> [options]

Run a subcommand with --help for its options.
Offline only: no network, no signing, no deployment, no key or secret is read.`;

// --- manifest subcommand ---------------------------------------------------

const MANIFEST_USAGE = `Usage:
  bun run ops -- manifest --recipients <file.json> --provenance <file.json> --out-dir <dir> [options]

Required:
  --recipients <file>   JSON: an array of addresses, or { "recipients": [...] }
  --provenance <file>   JSON: the approved provenance object
  --out-dir <dir>       directory to write manifest.json and manifest.json.sha256

Options:
  --batch-size <n>      batch size, 1..${MAX_BATCH_SIZE} (default 100)
  --force               overwrite existing output files
  --help                show this message`;

/** Accept either a bare JSON array of addresses or an object with a `recipients` array. */
export function parseRecipientsInput(raw: unknown, source: string): unknown[] {
  const list = Array.isArray(raw)
    ? raw
    : typeof raw === "object" && raw !== null && "recipients" in raw
      ? (raw as { recipients: unknown }).recipients
      : undefined;
  if (!Array.isArray(list)) {
    throw new Error(
      `${source}: expected a JSON array of addresses or { "recipients": [...] }`,
    );
  }
  return list;
}

export function parseBatchSize(raw: string | undefined): number {
  if (raw === undefined) return 100;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > MAX_BATCH_SIZE) {
    throw new Error(
      `--batch-size must be an integer in 1..${MAX_BATCH_SIZE}, got ${raw}`,
    );
  }
  return value;
}

function summarizeManifest(
  manifest: Manifest,
  checksum: string,
  paths: readonly string[],
): string {
  return [
    `recipients (derived cap)   : ${recipientCap(manifest)}`,
    `maximum supply (base units): ${maximumSupply(manifest)}`,
    `batch size                 : ${manifest.batchSize}`,
    `batch count                : ${splitBatches(manifest).length}`,
    `source chain / block       : ${manifest.provenance.sourceChainId} / ${manifest.provenance.snapshotBlockNumber}`,
    `source-data checksum       : ${manifest.provenance.sourceDataSha256}`,
    `ruleset / checksum         : ${manifest.provenance.rulesetId} / ${manifest.provenance.rulesetSha256}`,
    `manifest.json sha256       : ${checksum}`,
    "",
    ...paths.map((p) => `wrote ${p}`),
    "",
    `MREP2_RECIPIENT_CAP must be copied exactly from this manifest: ${recipientCap(manifest)}`,
  ].join("\n");
}

async function runManifest(argv: readonly string[]): Promise<number> {
  const options = {
    recipients: { type: "string" },
    provenance: { type: "string" },
    "out-dir": { type: "string" },
    "batch-size": { type: "string" },
    force: { type: "boolean", default: false },
    help: { type: "boolean", default: false },
  } as const;

  let values: ReturnType<
    typeof parseArgs<{ options: typeof options }>
  >["values"];
  try {
    values = parseArgs({
      args: [...argv],
      options,
      allowPositionals: false,
    }).values;
  } catch (error) {
    console.error(`${(error as Error).message}\n\n${MANIFEST_USAGE}`);
    return 2;
  }

  if (values.help) {
    console.log(MANIFEST_USAGE);
    return 0;
  }

  const missing = missingOptions(values, [
    "recipients",
    "provenance",
    "out-dir",
  ] as const);
  if (missing.length > 0) {
    console.error(
      `missing required option(s): ${missing.map((f) => `--${f}`).join(", ")}\n\n${MANIFEST_USAGE}`,
    );
    return 2;
  }

  const recipientsFile = values.recipients as string;
  const provenanceFile = values.provenance as string;
  const outDir = values["out-dir"] as string;

  const batchSize = parseBatchSize(values["batch-size"]);
  const recipients = parseRecipientsInput(
    await readJsonFile(recipientsFile),
    recipientsFile,
  );
  const provenance = await readJsonFile(provenanceFile);

  const manifest = buildManifest(recipients, provenance, batchSize);

  const json = manifestToJson(manifest);
  const checksum = sha256(json);
  const jsonPath = path.join(outDir, "manifest.json");
  const checksumPath = path.join(outDir, "manifest.json.sha256");

  await writeFiles(
    [
      { path: jsonPath, contents: json },
      { path: checksumPath, contents: `${checksum}\n` },
    ],
    values.force === true,
  );

  console.log(summarizeManifest(manifest, checksum, [jsonPath, checksumPath]));
  return 0;
}

// --- plan subcommand -------------------------------------------------------

const PLAN_USAGE = `Usage:
  bun run ops -- plan --manifest <file.json> --target-chain-id <n> --token <address> \\
    --source-commit <40-hex-sha> --runtime-bytecode-sha256 <sha256:...> --output <file.json> [options]

Required:
  --manifest <file>                 manifest.json produced by \`ops -- manifest\`
  --target-chain-id <n>             chain CHECKAUGUR is deployed on (may differ from the source chain)
  --token <address>                 the deployed candidate token address
  --source-commit <sha>             40-character hex git commit SHA the candidate was built from
  --runtime-bytecode-sha256 <hash>  sha256:<64 lowercase hex> of the candidate's runtime bytecode
  --output <file>                   path to write the distribution plan JSON to

Options:
  --manifest-sha256 <file>          detached checksum file to verify the manifest bytes against
  --force                           overwrite existing output files
  --help                            show this message`;

export function parseChainId(raw: string): number {
  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`--target-chain-id must be a positive integer, got ${raw}`);
  }
  return value;
}

function summarizePlan(
  plan: DistributionPlan,
  checksum: string,
  paths: readonly string[],
): string {
  const total = plan.batches.reduce((sum, b) => sum + b.recipients.length, 0);
  return [
    `target chain           : ${plan.targetChainId}`,
    `token address          : ${plan.token}`,
    `recipient count        : ${total}`,
    `batch count            : ${plan.batches.length}`,
    `source commit          : ${plan.sourceCommit}`,
    `runtime bytecode sha256: ${plan.runtimeBytecodeSha256}`,
    `manifest sha256        : ${plan.manifestSha256}`,
    `plan.json sha256       : ${checksum}`,
    "",
    ...paths.map((p) => `wrote ${p}`),
  ].join("\n");
}

async function runPlan(argv: readonly string[]): Promise<number> {
  const options = {
    manifest: { type: "string" },
    "manifest-sha256": { type: "string" },
    "target-chain-id": { type: "string" },
    token: { type: "string" },
    "source-commit": { type: "string" },
    "runtime-bytecode-sha256": { type: "string" },
    output: { type: "string" },
    force: { type: "boolean", default: false },
    help: { type: "boolean", default: false },
  } as const;

  let values: ReturnType<
    typeof parseArgs<{ options: typeof options }>
  >["values"];
  try {
    values = parseArgs({
      args: [...argv],
      options,
      allowPositionals: false,
    }).values;
  } catch (error) {
    console.error(`${(error as Error).message}\n\n${PLAN_USAGE}`);
    return 2;
  }

  if (values.help) {
    console.log(PLAN_USAGE);
    return 0;
  }

  const missing = missingOptions(values, [
    "manifest",
    "target-chain-id",
    "token",
    "source-commit",
    "runtime-bytecode-sha256",
    "output",
  ] as const);
  if (missing.length > 0) {
    console.error(
      `missing required option(s): ${missing.map((f) => `--${f}`).join(", ")}\n\n${PLAN_USAGE}`,
    );
    return 2;
  }

  const manifestFile = values.manifest as string;
  // Hash the exact manifest.json bytes, so the plan binds to that one file.
  const manifestText = await readTextFile(manifestFile);
  const manifestSha256 = sha256(manifestText);

  const expectedFile = values["manifest-sha256"];
  if (expectedFile !== undefined) {
    const expected = (await readTextFile(expectedFile)).trim();
    if (expected !== manifestSha256) {
      throw new Error(
        `manifest checksum mismatch: ${manifestFile} hashes to ${manifestSha256} but ${expectedFile} expects ${expected}`,
      );
    }
  }

  let manifestJson: unknown;
  try {
    manifestJson = JSON.parse(manifestText);
  } catch (error) {
    throw new Error(
      `${manifestFile}: invalid JSON (${(error as Error).message})`,
    );
  }
  const manifest = parseManifest(manifestJson);

  const plan = buildDistributionPlan({
    manifest,
    manifestSha256,
    targetChainId: parseChainId(values["target-chain-id"] as string),
    token: values.token as string,
    sourceCommit: values["source-commit"] as string,
    runtimeBytecodeSha256: values["runtime-bytecode-sha256"] as string,
  });

  const json = distributionPlanToJson(plan);
  const checksum = sha256(json);
  const outputFile = values.output as string;
  const checksumFile = `${outputFile}.sha256`;

  await writeFiles(
    [
      { path: outputFile, contents: json },
      { path: checksumFile, contents: `${checksum}\n` },
    ],
    values.force === true,
  );

  console.log(summarizePlan(plan, checksum, [outputFile, checksumFile]));
  return 0;
}

// --- dispatcher ------------------------------------------------------------

export async function main(argv: readonly string[]): Promise<number> {
  const [subcommand, ...rest] = argv;
  switch (subcommand) {
    case "manifest":
      return runManifest(rest);
    case "plan":
      return runPlan(rest);
    case "--help":
    case "help":
      console.log(TOP_USAGE);
      return 0;
    default:
      console.error(
        `${subcommand === undefined ? "missing subcommand" : `unknown subcommand: ${subcommand}`}\n\n${TOP_USAGE}`,
      );
      return 2;
  }
}

if (import.meta.main) {
  try {
    process.exit(await main(Bun.argv.slice(2)));
  } catch (error) {
    console.error(`error: ${(error as Error).message}`);
    process.exit(1);
  }
}
