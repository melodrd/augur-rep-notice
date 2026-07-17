import { describe, expect, test } from "bun:test";
import { getAddress } from "viem";
import {
  buildDistributionPlan,
  decodeDistribute,
  distributionPlanToJson,
  PLAN_VERSION,
} from "../src/distribution-plan.ts";
import {
  buildManifest,
  type Manifest,
  type Provenance,
} from "../src/manifest.ts";

function addr(n: number): string {
  return `0x${n.toString(16).padStart(40, "0")}`;
}

const SOURCE_CHAIN_ID = 1;
const TARGET_CHAIN_ID = 11155111;
const SOURCE_CONTRACT = getAddress(addr(0xabc123)) as `0x${string}`;
const COMMIT = "a".repeat(40);
const RUNTIME_HASH = `sha256:${"c".repeat(64)}`;
const MANIFEST_HASH = `sha256:${"d".repeat(64)}`;

/** Explicit fixture. Not a proposed REP snapshot, ruleset, or source contract. */
function provenance(overrides: Partial<Provenance> = {}): Provenance {
  return {
    sourceChainId: SOURCE_CHAIN_ID,
    snapshotBlockNumber: "21000000",
    snapshotBlockHash: `0x${"1".repeat(64)}`,
    sourceContracts: [SOURCE_CONTRACT],
    sourceDataSha256: `sha256:${"a".repeat(64)}`,
    rulesetId: "fixture-ruleset-v1",
    rulesetSha256: `sha256:${"b".repeat(64)}`,
    ...overrides,
  };
}

function manifestOf(count: number, batchSize: number): Manifest {
  const recipients = Array.from({ length: count }, (_, i) => addr(i + 1));
  return buildManifest(recipients, provenance(), batchSize);
}

/** A deployed token address that is not in any fixture recipient list. */
const DEPLOYED_TOKEN = getAddress(addr(0xdeadbeef)) as `0x${string}`;

function planOf(manifest: Manifest, token: string = DEPLOYED_TOKEN) {
  return buildDistributionPlan({
    manifest,
    manifestSha256: MANIFEST_HASH,
    targetChainId: TARGET_CHAIN_ID,
    token,
    sourceCommit: COMMIT,
    runtimeBytecodeSha256: RUNTIME_HASH,
  });
}

describe("buildDistributionPlan", () => {
  test("is deterministic", () => {
    const manifest = manifestOf(250, 100);
    expect(planOf(manifest)).toEqual(planOf(manifest));
  });

  test("stamps the version and binds token, chain, commit, and checksums", () => {
    const plan = planOf(manifestOf(3, 2));
    expect(plan.version).toBe(PLAN_VERSION);
    expect(plan.token).toBe(DEPLOYED_TOKEN);
    expect(plan.targetChainId).toBe(TARGET_CHAIN_ID);
    expect(plan.sourceCommit).toBe(COMMIT);
    expect(plan.runtimeBytecodeSha256).toBe(RUNTIME_HASH);
    expect(plan.manifestSha256).toBe(MANIFEST_HASH);
  });

  test("preserves the canonical manifest order and batch composition", () => {
    const manifest = manifestOf(250, 100);
    const plan = planOf(manifest);
    expect(plan.batches.map((b) => b.number)).toEqual([1, 2, 3]);
    expect(plan.batches.map((b) => b.recipients.length)).toEqual([
      100, 100, 50,
    ]);
    expect(plan.batches.flatMap((b) => b.recipients)).toEqual(
      manifest.recipients,
    );
  });

  test("encodes calldata that decodes to exactly the expected recipients", () => {
    const plan = planOf(manifestOf(250, 100));
    for (const batch of plan.batches) {
      expect([...decodeDistribute(batch.calldata)]).toEqual(batch.recipients);
      expect(batch.calldata.startsWith("0x")).toBe(true);
    }
  });

  test("allows the source and target chains to differ", () => {
    // A mainnet-source snapshot must drive a Sepolia rehearsal plan.
    const manifest = manifestOf(3, 2);
    expect(manifest.provenance.sourceChainId).toBe(SOURCE_CHAIN_ID);
    const plan = planOf(manifest);
    expect(plan.targetChainId).toBe(TARGET_CHAIN_ID);
    expect(plan.targetChainId).not.toBe(manifest.provenance.sourceChainId);
  });

  test("carries no nonce, fee, gas, key, signature, or broadcast fields", () => {
    const parsed = JSON.parse(distributionPlanToJson(planOf(manifestOf(3, 2))));
    for (const forbidden of [
      "nonce",
      "gas",
      "gasLimit",
      "gasPrice",
      "maxFeePerGas",
      "maxPriorityFeePerGas",
      "fee",
      "value",
      "privateKey",
      "signature",
      "broadcast",
    ]) {
      expect(parsed).not.toHaveProperty(forbidden);
      expect(parsed.batches[0]).not.toHaveProperty(forbidden);
    }
  });

  test("rejects the zero token address", () => {
    expect(() => planOf(manifestOf(3, 2), addr(0))).toThrow(
      /must not be the zero address/,
    );
  });

  test("rejects a malformed token address", () => {
    expect(() => planOf(manifestOf(3, 2), "0x123")).toThrow(
      /valid Ethereum address/,
    );
  });

  test("rejects a manifest recipient equal to the deployed token address", () => {
    const manifest = manifestOf(250, 100);
    const colliding = manifest.recipients[137] as `0x${string}`;
    expect(colliding).toBeDefined();
    expect(() => planOf(manifest, colliding)).toThrow(
      /token contract cannot be a recipient/,
    );
    expect(() => planOf(manifest, colliding.toLowerCase())).toThrow(
      /token contract cannot be a recipient/,
    );
  });

  test("rejects an invalid target chain", () => {
    const manifest = manifestOf(3, 2);
    expect(() =>
      buildDistributionPlan({
        manifest,
        manifestSha256: MANIFEST_HASH,
        targetChainId: 0,
        token: DEPLOYED_TOKEN,
        sourceCommit: COMMIT,
        runtimeBytecodeSha256: RUNTIME_HASH,
      }),
    ).toThrow(/targetChainId must be a positive integer/);
  });

  test("rejects a malformed source commit or runtime bytecode checksum", () => {
    const manifest = manifestOf(3, 2);
    expect(() =>
      buildDistributionPlan({
        manifest,
        manifestSha256: MANIFEST_HASH,
        targetChainId: TARGET_CHAIN_ID,
        token: DEPLOYED_TOKEN,
        sourceCommit: "abc1234",
        runtimeBytecodeSha256: RUNTIME_HASH,
      }),
    ).toThrow(/sourceCommit/);
    expect(() =>
      buildDistributionPlan({
        manifest,
        manifestSha256: MANIFEST_HASH,
        targetChainId: TARGET_CHAIN_ID,
        token: DEPLOYED_TOKEN,
        sourceCommit: COMMIT,
        runtimeBytecodeSha256: "c".repeat(64),
      }),
    ).toThrow(/runtimeBytecodeSha256/);
  });

  test("rejects a malformed manifest checksum", () => {
    const manifest = manifestOf(3, 2);
    expect(() =>
      buildDistributionPlan({
        manifest,
        manifestSha256: "d".repeat(64),
        targetChainId: TARGET_CHAIN_ID,
        token: DEPLOYED_TOKEN,
        sourceCommit: COMMIT,
        runtimeBytecodeSha256: RUNTIME_HASH,
      }),
    ).toThrow(/manifestSha256/);
  });

  test("re-validates the manifest and rejects one tampered after being built", () => {
    // Satisfies the Manifest type but has an unsorted recipient list; parseManifest must catch it.
    const manifest = manifestOf(3, 5);
    const tampered: Manifest = {
      ...manifest,
      recipients: [...manifest.recipients].reverse(),
    };
    expect(() => planOf(tampered)).toThrow(/not sorted ascending/);
  });

  test("does not mutate the input manifest", () => {
    const manifest = manifestOf(250, 100);
    const snapshot = JSON.parse(JSON.stringify(manifest));
    const plan = planOf(manifest);
    plan.batches[0]?.recipients.push(addr(999) as `0x${string}`);
    expect(JSON.parse(JSON.stringify(manifest))).toEqual(snapshot);
  });
});

describe("distributionPlanToJson", () => {
  test("round-trips the plan structure", () => {
    const plan = planOf(manifestOf(3, 2));
    const json = distributionPlanToJson(plan);
    expect(json.endsWith("\n")).toBe(true);
    expect(JSON.parse(json)).toEqual(plan);
  });
});
