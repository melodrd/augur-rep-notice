// Offline recipient-manifest command.
//
//   bun run manifest -- \
//     --recipients data/snapshots/approved-recipients.json \
//     --provenance data/snapshots/approved-provenance.json \
//     --batch-size 100 \
//     --out-dir data/batches/candidate-1
//
// It reads two explicit JSON files, builds the deterministic manifest, and writes manifest.json
// and manifest.csv. It makes no network request, signs nothing, deploys nothing, and reads no
// private key, mnemonic, keystore, or API key. It refuses to overwrite an existing output file
// unless --force is passed explicitly.
//
// The recipient cap is derived from the recipient list; it cannot be supplied here. Provenance is
// never defaulted or invented: the file must contain reviewed, human-supplied values.

import { parseArgs } from "node:util";
import path from "node:path";

import {
  buildManifest,
  type Manifest,
  manifestToCsv,
  manifestToJson,
  MAX_BATCH_SIZE,
  type RecipientProvenance,
} from "./manifest.ts";

const USAGE = `Usage:
  bun run manifest -- --recipients <file.json> --provenance <file.json> --out-dir <dir> [options]

Required:
  --recipients <file>   JSON: an array of addresses, or { "recipients": [...] }
  --provenance <file>   JSON: the approved RecipientProvenance object
  --out-dir <dir>       directory to write manifest.json and manifest.csv into

Options:
  --batch-size <n>      operational batch size, 1..${MAX_BATCH_SIZE} (default 100)
  --force               overwrite existing output files
  --help                show this message

Offline only: no network, no signing, no deployment, no key or secret is read.`;

/**
 * Accept either a bare JSON array of addresses or an object with a `recipients` array. Anything
 * else is rejected rather than coerced: this tool never repairs its input.
 */
export function parseRecipientsInput(raw: unknown, source: string): string[] {
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
  list.forEach((entry, index) => {
    if (typeof entry !== "string") {
      throw new Error(`${source}: recipient at index ${index} is not a string`);
    }
  });
  return list as string[];
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

async function writeOutput(
  file: string,
  contents: string,
  force: boolean,
): Promise<void> {
  if (!force && (await Bun.file(file).exists())) {
    throw new Error(
      `refusing to overwrite existing file: ${file} (pass --force to authorize)`,
    );
  }
  await Bun.write(file, contents);
}

function summarize(manifest: Manifest): string {
  const lines = [
    `schema version                : ${manifest.schemaVersion}`,
    `recipients (derived cap)      : ${manifest.recipientCap}`,
    `maximum supply (base units)   : ${manifest.maximumSupply}`,
    `operational batch size        : ${manifest.operationalBatchSize}`,
    `batches                       : ${manifest.batches.length}`,
    `snapshot chain / block        : ${manifest.provenance.chainId} / ${manifest.provenance.snapshotBlockNumber}`,
    `canonical recipients checksum : ${manifest.canonicalRecipientsChecksum}`,
    `source data checksum          : ${manifest.provenance.sourceDataChecksum}`,
    `ruleset / checksum            : ${manifest.provenance.rulesetId} / ${manifest.provenance.rulesetChecksum}`,
    `manifest checksum             : ${manifest.manifestChecksum}`,
    "",
    `MREP2_RECIPIENT_CAP must be copied exactly from this manifest: ${manifest.recipientCap}`,
  ];
  return lines.join("\n");
}

export async function main(argv: readonly string[]): Promise<number> {
  let parsed: ReturnType<typeof parseArgs<{ options: typeof options }>>;
  const options = {
    recipients: { type: "string" },
    provenance: { type: "string" },
    "out-dir": { type: "string" },
    "batch-size": { type: "string" },
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

  const missing = (["recipients", "provenance", "out-dir"] as const).filter(
    (flag) => !values[flag],
  );
  if (missing.length > 0) {
    console.error(
      `missing required option(s): ${missing.map((f) => `--${f}`).join(", ")}\n\n${USAGE}`,
    );
    return 2;
  }

  const recipientsFile = values.recipients as string;
  const provenanceFile = values.provenance as string;
  const outDir = values["out-dir"] as string;

  const batchSize = parseBatchSize(values["batch-size"]);
  const recipients = parseRecipientsInput(
    await readJson(recipientsFile),
    recipientsFile,
  );
  const provenance = (await readJson(provenanceFile)) as RecipientProvenance;

  const manifest = buildManifest(recipients, { batchSize, provenance });

  const jsonPath = path.join(outDir, "manifest.json");
  const csvPath = path.join(outDir, "manifest.csv");
  const force = values.force === true;

  // Check both destinations before writing either, so a refusal never leaves a partial output.
  for (const file of [jsonPath, csvPath]) {
    if (!force && (await Bun.file(file).exists())) {
      throw new Error(
        `refusing to overwrite existing file: ${file} (pass --force to authorize)`,
      );
    }
  }
  await writeOutput(jsonPath, manifestToJson(manifest), force);
  await writeOutput(csvPath, manifestToCsv(manifest), force);

  console.log(summarize(manifest));
  console.log(`\nwrote ${jsonPath}`);
  console.log(`wrote ${csvPath}`);
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
