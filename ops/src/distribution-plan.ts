// Offline post-deployment distribution planning for MigrateRepV2Token (MREP2).
//
// The final token address does not exist when a recipient snapshot is prepared, so an approved
// manifest cannot name it. This module performs the one deterministic step that binds an approved
// manifest to a specific deployed candidate: it re-checks the recipient list against the now-known
// token address, encodes the exact `distribute(address[])` calldata for each batch in the manifest's
// order, and records checksums and expected accounting for human review.
//
// It performs no RPC request, no signing, and no broadcasting, and it reads no key or secret. It is
// not a transaction framework: it deliberately records no nonce, fee, or gas figure, because any
// such value produced here would be a guess presented as authoritative. The human preparing the
// transaction supplies those from the live chain under a separately authorized task.
//
// The generated plan is intended to be diffed against the decoded transaction in a signing UI: for
// each batch, the calldata here must byte-for-byte equal what is about to be signed.

import { createHash } from "node:crypto";
import {
  decodeFunctionData,
  encodeFunctionData,
  getAddress,
  isAddress,
} from "viem";

import { type Manifest, validateManifest } from "./manifest.ts";

/** Distribution-plan schema version. */
export const PLAN_SCHEMA_VERSION = 1;

/** The exact and only function this plan ever encodes. */
export const DISTRIBUTE_ABI = [
  {
    type: "function",
    name: "distribute",
    stateMutability: "nonpayable",
    inputs: [{ name: "recipients", type: "address[]" }],
    outputs: [],
  },
] as const;

export const DISTRIBUTE_SIGNATURE = "distribute(address[])";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const SHA256_CHECKSUM = /^sha256:[0-9a-f]{64}$/;
const GIT_COMMIT = /^[0-9a-f]{40}$/;

/**
 * A plan is deliberately not a transaction. It carries no nonce, fee, gas limit, or signature:
 * those are supplied by the human operator from live chain state at signing time.
 */
export const UNSIGNED_PLAN_NOTICE =
  "Offline plan. Contains no nonce, fee, gas, or signature: supply those from live chain state at signing time. Compare each batch's calldata byte-for-byte against the decoded transaction before signing.";

export interface DistributionPlanInput {
  /** The approved manifest. Never mutated. */
  manifest: Manifest;
  /** The chain the distribution will run on. Must match the manifest's snapshot chain. */
  chainId: number;
  /** The deployed candidate token address. */
  deployedToken: string;
  /** The frozen source commit the candidate was built from (40-hex git SHA). */
  candidateSourceCommit: string;
  /** Checksum of the candidate's runtime bytecode, as `sha256:<64 lowercase hex>`. */
  runtimeBytecodeHash: string;
}

export interface DistributionPlanBatch {
  batchNumber: number;
  recipientCount: number;
  firstAddress: `0x${string}`;
  lastAddress: `0x${string}`;
  recipients: `0x${string}`[];
  /** Propagated from the manifest so a batch can be traced back to the approved document. */
  batchChecksum: string;
  /** Exact ABI-encoded `distribute(address[])` payload for this batch. */
  calldata: `0x${string}`;
  /** Checksum of the calldata payload above. */
  calldataChecksum: string;
  /** `totalInitialRecipients` expected on chain after this batch confirms. */
  expectedCumulativeInitialRecipientsAfter: number;
  /**
   * Remaining initial allocation after this batch: `(recipientCap - cumulative) * TOKEN_PER_RECIPIENT`.
   * Not a prediction of `balanceOf(token)`, which may be larger if holders return tokens.
   */
  expectedRemainingInitialAllocationAfter: string;
}

export interface DistributionPlan {
  schemaVersion: number;
  notice: string;
  chainId: number;
  deployedToken: `0x${string}`;
  candidateSourceCommit: string;
  runtimeBytecodeHash: string;
  /** Binds this plan to one exact approved manifest. */
  manifestChecksum: string;
  manifestSchemaVersion: number;
  functionSignature: string;
  tokenPerRecipient: string;
  recipientCap: string;
  maximumSupply: string;
  totalBatches: number;
  totalRecipients: number;
  batches: DistributionPlanBatch[];
  planChecksum: string;
}

function sha256(data: string): string {
  return `sha256:${createHash("sha256").update(data, "utf8").digest("hex")}`;
}

/**
 * Bind an approved manifest to a deployed candidate. Pure and deterministic: no I/O, no network,
 * no signing, no mutation of the input manifest, and identical inputs always produce an identical
 * plan including every checksum.
 *
 * The manifest is independently re-validated with `validateManifest` before anything else runs:
 * satisfying the `Manifest` type is not evidence that a manifest is genuine, so a manifest read
 * from disk (or otherwise constructed outside `buildManifest`) is never trusted on the strength
 * of its checksums or its TypeScript type alone.
 */
export function buildDistributionPlan(
  input: DistributionPlanInput,
): DistributionPlan {
  const { chainId, deployedToken, candidateSourceCommit, runtimeBytecodeHash } =
    input;
  const manifest = validateManifest(input.manifest);

  if (!Number.isInteger(chainId) || chainId <= 0) {
    throw new Error(`chainId must be a positive integer, got ${chainId}`);
  }
  if (chainId !== manifest.provenance.chainId) {
    throw new Error(
      `chain mismatch: plan targets chain ${chainId} but the manifest snapshot is from chain ${manifest.provenance.chainId}`,
    );
  }

  if (typeof deployedToken !== "string" || !isAddress(deployedToken)) {
    throw new Error(
      `deployedToken must be a valid Ethereum address, got ${String(deployedToken)}`,
    );
  }
  if (deployedToken.toLowerCase() === ZERO_ADDRESS) {
    throw new Error("deployedToken must not be the zero address");
  }
  const token = getAddress(deployedToken) as `0x${string}`;

  if (!GIT_COMMIT.test(candidateSourceCommit)) {
    throw new Error(
      "candidateSourceCommit must be a full 40-character hex git commit SHA",
    );
  }
  if (!SHA256_CHECKSUM.test(runtimeBytecodeHash)) {
    throw new Error(
      "runtimeBytecodeHash must look like sha256:<64 lowercase hex>",
    );
  }

  if (manifest.batches.length === 0) {
    throw new Error("manifest contains no batches");
  }

  // The manifest was approved before the token address existed, so this is the first point at
  // which the token contract can be excluded from its own recipient list. The contract rejects it
  // on chain too; catching it here means a bad batch is never prepared, let alone signed.
  manifest.batches.forEach((batch) => {
    batch.recipients.forEach((recipient, index) => {
      if (recipient.toLowerCase() === token.toLowerCase()) {
        throw new Error(
          `manifest batch ${batch.batchNumber} index ${index} is the deployed token address ${token}: the token contract cannot be an initial recipient`,
        );
      }
    });
  });

  const recipientCap = BigInt(manifest.recipientCap);
  const tokenPerRecipient = BigInt(manifest.tokenPerRecipient);

  let cumulative = 0;
  const batches: DistributionPlanBatch[] = manifest.batches.map((batch) => {
    // Recipient order and batch composition come from the approved manifest unchanged.
    const recipients = [...batch.recipients];
    cumulative += recipients.length;

    const calldata = encodeFunctionData({
      abi: DISTRIBUTE_ABI,
      functionName: "distribute",
      args: [recipients],
    });

    const remaining = (recipientCap - BigInt(cumulative)) * tokenPerRecipient;

    return {
      batchNumber: batch.batchNumber,
      recipientCount: recipients.length,
      firstAddress: batch.firstAddress,
      lastAddress: batch.lastAddress,
      recipients,
      batchChecksum: batch.batchChecksum,
      calldata,
      calldataChecksum: sha256(calldata),
      expectedCumulativeInitialRecipientsAfter: cumulative,
      expectedRemainingInitialAllocationAfter: remaining.toString(10),
    };
  });

  const withoutPlanChecksum: Omit<DistributionPlan, "planChecksum"> = {
    schemaVersion: PLAN_SCHEMA_VERSION,
    notice: UNSIGNED_PLAN_NOTICE,
    chainId,
    deployedToken: token,
    candidateSourceCommit,
    runtimeBytecodeHash,
    manifestChecksum: manifest.manifestChecksum,
    manifestSchemaVersion: manifest.schemaVersion,
    functionSignature: DISTRIBUTE_SIGNATURE,
    tokenPerRecipient: manifest.tokenPerRecipient,
    recipientCap: manifest.recipientCap,
    maximumSupply: manifest.maximumSupply,
    totalBatches: batches.length,
    totalRecipients: cumulative,
    batches,
  };

  return {
    ...withoutPlanChecksum,
    planChecksum: sha256(JSON.stringify(withoutPlanChecksum)),
  };
}

/**
 * Decode a batch's calldata back to its recipient array. Provided so a reviewer can re-derive the
 * recipients from the bytes that will actually be signed, rather than trusting the plan's own
 * recipient field.
 */
export function decodeDistributeCalldata(
  calldata: `0x${string}`,
): readonly `0x${string}`[] {
  const decoded = decodeFunctionData({ abi: DISTRIBUTE_ABI, data: calldata });
  if (decoded.functionName !== "distribute") {
    throw new Error(`unexpected function: ${decoded.functionName}`);
  }
  return decoded.args[0];
}

/** Deterministic pretty JSON serialization. */
export function distributionPlanToJson(plan: DistributionPlan): string {
  return `${JSON.stringify(plan, null, 2)}\n`;
}
