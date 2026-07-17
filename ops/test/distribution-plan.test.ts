import { describe, expect, test } from "bun:test";
import { getAddress } from "viem";
import {
  buildDistributionPlan,
  decodeDistributeCalldata,
  DISTRIBUTE_SIGNATURE,
  distributionPlanToJson,
  PLAN_SCHEMA_VERSION,
} from "../src/distribution-plan.ts";
import {
  buildManifest,
  type Manifest,
  type RecipientProvenance,
  TOKEN_PER_RECIPIENT,
} from "../src/manifest.ts";

function addr(n: number): string {
  return `0x${n.toString(16).padStart(40, "0")}`;
}

const CHAIN_ID = 1;
const SOURCE_CONTRACT = getAddress(addr(0xabc123)) as `0x${string}`;
const COMMIT = "a".repeat(40);
const RUNTIME_HASH = `sha256:${"c".repeat(64)}`;

/** Explicit fixture. Not a proposed REP snapshot, ruleset, or source contract. */
function provenance(
  overrides: Partial<RecipientProvenance> = {},
): RecipientProvenance {
  return {
    chainId: CHAIN_ID,
    snapshotBlockNumber: "21000000",
    snapshotBlockHash: `0x${"1".repeat(64)}`,
    sourceContracts: [SOURCE_CONTRACT],
    sourceDataChecksum: `sha256:${"a".repeat(64)}`,
    rulesetId: "fixture-ruleset-v1",
    rulesetChecksum: `sha256:${"b".repeat(64)}`,
    ...overrides,
  };
}

function manifestOf(count: number, batchSize: number): Manifest {
  const recipients = Array.from({ length: count }, (_, i) => addr(i + 1));
  return buildManifest(recipients, { batchSize, provenance: provenance() });
}

/** A deployed token address that is not in any fixture recipient list. */
const DEPLOYED_TOKEN = getAddress(addr(0xdeadbeef)) as `0x${string}`;

function planOf(manifest: Manifest, deployedToken: string = DEPLOYED_TOKEN) {
  return buildDistributionPlan({
    manifest,
    chainId: CHAIN_ID,
    deployedToken,
    candidateSourceCommit: COMMIT,
    runtimeBytecodeHash: RUNTIME_HASH,
  });
}

describe("buildDistributionPlan", () => {
  test("is deterministic", () => {
    const manifest = manifestOf(250, 100);
    expect(planOf(manifest)).toEqual(planOf(manifest));
  });

  test("stamps the schema version, signature, and unsigned notice", () => {
    const plan = planOf(manifestOf(3, 2));
    expect(plan.schemaVersion).toBe(PLAN_SCHEMA_VERSION);
    expect(plan.functionSignature).toBe(DISTRIBUTE_SIGNATURE);
    expect(plan.notice).toMatch(/no nonce, fee, gas, or signature/);
  });

  test("records no nonce, fee, or gas figure", () => {
    const parsed = JSON.parse(distributionPlanToJson(planOf(manifestOf(3, 2))));
    for (const forbidden of [
      "nonce",
      "gas",
      "gasLimit",
      "gasPrice",
      "maxFeePerGas",
      "maxPriorityFeePerGas",
      "value",
      "signature",
    ]) {
      expect(parsed).not.toHaveProperty(forbidden);
      expect(parsed.batches[0]).not.toHaveProperty(forbidden);
    }
  });

  test("preserves the manifest recipient order and batch composition", () => {
    const manifest = manifestOf(250, 100);
    const plan = planOf(manifest);

    expect(plan.batches.map((b) => b.batchNumber)).toEqual([1, 2, 3]);
    expect(plan.batches.map((b) => b.recipientCount)).toEqual([100, 100, 50]);
    expect(plan.batches.map((b) => b.recipients)).toEqual(
      manifest.batches.map((b) => b.recipients),
    );
    expect(plan.batches.map((b) => b.batchChecksum)).toEqual(
      manifest.batches.map((b) => b.batchChecksum),
    );
  });

  test("encodes calldata that decodes back to the exact recipient array", () => {
    const manifest = manifestOf(250, 100);
    const plan = planOf(manifest);

    plan.batches.forEach((batch) => {
      const decoded = decodeDistributeCalldata(batch.calldata);
      expect([...decoded]).toEqual(batch.recipients);
      // Selector of distribute(address[]), then a standard dynamic-array encoding.
      expect(batch.calldata.startsWith("0x")).toBe(true);
      expect(batch.calldataChecksum).toMatch(/^sha256:[0-9a-f]{64}$/);
    });
  });

  test("propagates the manifest checksum and cap", () => {
    const manifest = manifestOf(250, 100);
    const plan = planOf(manifest);
    expect(plan.manifestChecksum).toBe(manifest.manifestChecksum);
    expect(plan.manifestSchemaVersion).toBe(manifest.schemaVersion);
    expect(plan.recipientCap).toBe("250");
    expect(plan.maximumSupply).toBe(manifest.maximumSupply);
    expect(plan.totalRecipients).toBe(250);
    expect(plan.totalBatches).toBe(3);
  });

  test("a different manifest yields a different plan checksum", () => {
    const a = planOf(manifestOf(250, 100));
    const b = planOf(manifestOf(250, 50));
    expect(b.planChecksum).not.toBe(a.planChecksum);
  });

  test("records correct cumulative accounting per batch", () => {
    const plan = planOf(manifestOf(250, 100));

    expect(
      plan.batches.map((b) => b.expectedCumulativeInitialRecipientsAfter),
    ).toEqual([100, 200, 250]);
    expect(
      plan.batches.map((b) => b.expectedRemainingInitialAllocationAfter),
    ).toEqual([
      (150n * TOKEN_PER_RECIPIENT).toString(10),
      (50n * TOKEN_PER_RECIPIENT).toString(10),
      "0",
    ]);
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
    // Pick a real recipient out of the middle of the list and "deploy" the token there.
    const collidingRecipient = manifest.batches[1]
      ?.recipients[7] as `0x${string}`;
    expect(collidingRecipient).toBeDefined();

    expect(() => planOf(manifest, collidingRecipient)).toThrow(
      /the token contract cannot be an initial recipient/,
    );
    expect(() => planOf(manifest, collidingRecipient.toLowerCase())).toThrow(
      /the token contract cannot be an initial recipient/,
    );
  });

  test("rejects a chain mismatch against the manifest snapshot", () => {
    const manifest = manifestOf(3, 2);
    expect(() =>
      buildDistributionPlan({
        manifest,
        chainId: 11155111,
        deployedToken: DEPLOYED_TOKEN,
        candidateSourceCommit: COMMIT,
        runtimeBytecodeHash: RUNTIME_HASH,
      }),
    ).toThrow(/chain mismatch/);
  });

  test("rejects a non-positive chain ID", () => {
    const manifest = manifestOf(3, 2);
    expect(() =>
      buildDistributionPlan({
        manifest,
        chainId: 0,
        deployedToken: DEPLOYED_TOKEN,
        candidateSourceCommit: COMMIT,
        runtimeBytecodeHash: RUNTIME_HASH,
      }),
    ).toThrow(/chainId must be a positive integer/);
  });

  test("rejects a malformed source commit or runtime bytecode hash", () => {
    const manifest = manifestOf(3, 2);
    expect(() =>
      buildDistributionPlan({
        manifest,
        chainId: CHAIN_ID,
        deployedToken: DEPLOYED_TOKEN,
        candidateSourceCommit: "abc1234",
        runtimeBytecodeHash: RUNTIME_HASH,
      }),
    ).toThrow(/candidateSourceCommit/);
    expect(() =>
      buildDistributionPlan({
        manifest,
        chainId: CHAIN_ID,
        deployedToken: DEPLOYED_TOKEN,
        candidateSourceCommit: COMMIT,
        runtimeBytecodeHash: "c".repeat(64),
      }),
    ).toThrow(/runtimeBytecodeHash/);
  });

  test("does not mutate the input manifest", () => {
    const manifest = manifestOf(250, 100);
    const snapshot = JSON.parse(JSON.stringify(manifest));

    const plan = planOf(manifest);
    plan.batches[0]?.recipients.push(addr(999) as `0x${string}`);

    expect(JSON.parse(JSON.stringify(manifest))).toEqual(snapshot);
  });

  test("rejects a manifest tampered after being built, even though it still satisfies the Manifest type", () => {
    // A single batch (batchSize > count) keeps the fixture to one remaining-allocation figure.
    const manifest = manifestOf(3, 5);
    const tamperedCap = 999n;
    const tampered: Manifest = {
      ...manifest,
      recipientCap: tamperedCap.toString(10),
      batches: manifest.batches.map((batch) => ({
        ...batch,
        // Keep this figure consistent with the tampered cap so the test isolates the
        // recipientCap/count cross-check rather than tripping an earlier one.
        expectedRemainingInitialAllocationAfter: (
          (tamperedCap - BigInt(batch.cumulativeRecipients)) *
          TOKEN_PER_RECIPIENT
        ).toString(10),
      })),
    };
    expect(() => planOf(tampered)).toThrow(
      /recipientCap 999 does not equal the total unique recipient count 3/,
    );
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
