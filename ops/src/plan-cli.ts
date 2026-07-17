// Offline post-deployment distribution-plan command.
//
//   bun run plan -- \
//     --manifest data/batches/candidate-1/manifest.json \
//     --chain-id 1 \
//     --token 0xDeployedTokenAddress... \
//     --source-commit <40-character hex git commit SHA> \
//     --runtime-bytecode-hash sha256:<64 lowercase hex> \
//     --output data/plans/candidate-1/plan.json
//
// It reads one manifest file, independently validates it (never trusting its TypeScript type or
// the checksums it already carries), binds it to a deployed candidate, and writes the resulting
// distribution plan as JSON. It makes no network request, signs nothing, broadcasts nothing, and
// reads no private key, mnemonic, keystore, or API key. It refuses to overwrite an existing output
// file unless --force is passed explicitly.

import { parseArgs } from "node:util";

import {
  buildDistributionPlan,
  type DistributionPlan,
  distributionPlanToJson,
} from "./distribution-plan.ts";
import { validateManifest } from "./manifest.ts";

const USAGE = `Usage:
  bun run plan -- --manifest <file.json> --chain-id <n> --token <address> \\
    --source-commit <40-hex-sha> --runtime-bytecode-hash <sha256:...> --output <file.json> [options]

Required:
  --manifest <file>              JSON manifest produced by \`bun run manifest\`
  --chain-id <n>                 chain the distribution will run on
  --token <address>               the deployed candidate token address
  --source-commit <sha>          40-character hex git commit SHA the candidate was built from
  --runtime-bytecode-hash <hash> sha256:<64 lowercase hex> of the candidate's runtime bytecode
  --output <file>                path to write the distribution plan JSON to

Options:
  --force                        overwrite an existing output file
  --help                         show this message

Offline only: no network, no signing, no deployment, no key or secret is read.`;

export function parseChainId(raw: string): number {
  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`--chain-id must be a positive integer, got ${raw}`);
  }
  return value;
}

async function readJson(file: string): Promise<unknown> {
  const handle = Bun.file(file);
  if (!(await handle.exists())) {
    throw new Error(`no such file: ${file}`);
  }
  try {
    return JSON.parse(await handle.text());
  } catch (error) {
    throw new Error(`${file}: invalid JSON (${(error as Error).message})`);
  }
}

function summarize(plan: DistributionPlan, outputFile: string): string {
  const lines = [
    `chain                 : ${plan.chainId}`,
    `token address         : ${plan.deployedToken}`,
    `recipient count       : ${plan.totalRecipients}`,
    `batch count           : ${plan.totalBatches}`,
    `manifest checksum     : ${plan.manifestChecksum}`,
    `plan checksum         : ${plan.planChecksum}`,
    `output path           : ${outputFile}`,
  ];
  return lines.join("\n");
}

export async function main(argv: readonly string[]): Promise<number> {
  let parsed: ReturnType<typeof parseArgs<{ options: typeof options }>>;
  const options = {
    manifest: { type: "string" },
    "chain-id": { type: "string" },
    token: { type: "string" },
    "source-commit": { type: "string" },
    "runtime-bytecode-hash": { type: "string" },
    output: { type: "string" },
    force: { type: "boolean", default: false },
    help: { type: "boolean", default: false },
  } as const;

  try {
    parsed = parseArgs({ args: [...argv], options, allowPositionals: false });
  } catch (error) {
    console.error(`${(error as Error).message}\n\n${USAGE}`);
    return 2;
  }

  const values = parsed.values;
  if (values.help) {
    console.log(USAGE);
    return 0;
  }

  const missing = (
    [
      "manifest",
      "chain-id",
      "token",
      "source-commit",
      "runtime-bytecode-hash",
      "output",
    ] as const
  ).filter((flag) => !values[flag]);
  if (missing.length > 0) {
    console.error(
      `missing required option(s): ${missing.map((f) => `--${f}`).join(", ")}\n\n${USAGE}`,
    );
    return 2;
  }

  const manifestFile = values.manifest as string;
  const chainId = parseChainId(values["chain-id"] as string);
  const token = values.token as string;
  const candidateSourceCommit = values["source-commit"] as string;
  const runtimeBytecodeHash = values["runtime-bytecode-hash"] as string;
  const outputFile = values.output as string;
  const force = values.force === true;

  // Never trust the file's TypeScript type or its own checksums: independently recompute and
  // verify everything before this manifest is used to derive any calldata.
  const manifest = validateManifest(await readJson(manifestFile));

  const plan = buildDistributionPlan({
    manifest,
    chainId,
    deployedToken: token,
    candidateSourceCommit,
    runtimeBytecodeHash,
  });

  if (!force && (await Bun.file(outputFile).exists())) {
    throw new Error(
      `refusing to overwrite existing file: ${outputFile} (pass --force to authorize)`,
    );
  }
  await Bun.write(outputFile, distributionPlanToJson(plan));

  console.log(summarize(plan, outputFile));
  return 0;
}

if (import.meta.main) {
  try {
    process.exit(await main(Bun.argv.slice(2)));
  } catch (error) {
    console.error(`error: ${(error as Error).message}`);
    process.exit(1);
  }
}
