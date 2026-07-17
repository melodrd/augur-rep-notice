// Small shared helpers for the offline CLI: detached SHA-256 checksums, reading input files, and
// writing outputs without clobbering. No network, no keys, no secrets.

import { createHash } from "node:crypto";

/** Detached SHA-256 of a string, tagged `sha256:` to match the checksum convention used elsewhere. */
export function sha256(data: string): string {
  return `sha256:${createHash("sha256").update(data, "utf8").digest("hex")}`;
}

export async function readTextFile(file: string): Promise<string> {
  const handle = Bun.file(file);
  if (!(await handle.exists())) {
    throw new Error(`no such file: ${file}`);
  }
  return handle.text();
}

export async function readJsonFile(file: string): Promise<unknown> {
  const text = await readTextFile(file);
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`${file}: invalid JSON (${(error as Error).message})`);
  }
}

/**
 * Write a set of output files. When not forcing, every destination is checked before any is
 * written, so a refusal never leaves a partial set of outputs behind.
 */
export async function writeFiles(
  files: readonly { path: string; contents: string }[],
  force: boolean,
): Promise<void> {
  if (!force) {
    for (const { path } of files) {
      if (await Bun.file(path).exists()) {
        throw new Error(
          `refusing to overwrite existing file: ${path} (pass --force to authorize)`,
        );
      }
    }
  }
  for (const { path, contents } of files) {
    await Bun.write(path, contents);
  }
}

/** Names of required options that are missing (falsy) from a parsed argument set. */
export function missingOptions<T extends string>(
  values: Record<string, unknown>,
  required: readonly T[],
): T[] {
  return required.filter((name) => !values[name]);
}
