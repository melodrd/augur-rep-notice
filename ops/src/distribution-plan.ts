// Offline binding of an approved manifest to a deployed MREP2 candidate.
//
// The token address does not exist when a recipient snapshot is prepared, so the manifest cannot
// name it. This is the one deterministic step that binds an approved manifest to a specific
// deployed token: it re-validates the manifest, re-checks the recipient list against the now-known
// token address, splits it into batches, and encodes the exact distribute(address[]) calldata for
// each batch. It then decodes that calldata and asserts the decoded recipients exactly equal the
// batch, so a mis-encoded payload can never reach a signer.
//
// It performs no RPC request, no signing, and no broadcasting, and reads no key or secret. It
// records no nonce, fee, or gas: those come from live chain state under a separately authorized
// task. `targetChainId` (where MREP2 is deployed) is intentionally independent of the manifest's
// `sourceChainId` (where the snapshot was read), so a mainnet snapshot can drive a Sepolia plan.

import {
  decodeFunctionData,
  encodeFunctionData,
  getAddress,
  isAddress,
} from "viem";

import {
  type Batch,
  type Manifest,
  parseManifest,
  splitBatches,
} from "./manifest.ts";

/** The only plan format this tool writes. */
export const PLAN_VERSION = 1;

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

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const SHA256 = /^sha256:[0-9a-f]{64}$/;
const GIT_COMMIT = /^[0-9a-f]{40}$/;

export interface PlanInput {
  /** The approved manifest. Re-validated before use; never mutated. */
  manifest: Manifest;
  /** SHA-256 of the exact manifest.json bytes this plan is bound to. */
  manifestSha256: string;
  /** The chain MREP2 is deployed on. May differ from the manifest's source chain. */
  targetChainId: number;
  /** The deployed candidate token address. */
  token: string;
  /** The frozen source commit the candidate was built from (40-hex git SHA). */
  sourceCommit: string;
  /** SHA-256 of the candidate's runtime bytecode, as `sha256:<64 lowercase hex>`. */
  runtimeBytecodeSha256: string;
}

export interface PlanBatch {
  number: number;
  recipients: `0x${string}`[];
  /** Exact ABI-encoded distribute(address[]) payload; equals what the signer must sign. */
  calldata: `0x${string}`;
}

export interface DistributionPlan {
  version: number;
  targetChainId: number;
  token: `0x${string}`;
  sourceCommit: string;
  runtimeBytecodeSha256: string;
  manifestSha256: string;
  batches: PlanBatch[];
}

/** Encode the distribute(address[]) calldata for one batch of recipients. */
export function encodeDistribute(
  recipients: readonly `0x${string}`[],
): `0x${string}` {
  return encodeFunctionData({
    abi: DISTRIBUTE_ABI,
    functionName: "distribute",
    args: [recipients as `0x${string}`[]],
  });
}

/**
 * Decode a batch's calldata back to its recipient array, so a reviewer can re-derive the
 * recipients from the bytes that will actually be signed rather than trusting the plan's own field.
 */
export function decodeDistribute(
  calldata: `0x${string}`,
): readonly `0x${string}`[] {
  const decoded = decodeFunctionData({ abi: DISTRIBUTE_ABI, data: calldata });
  if (decoded.functionName !== "distribute") {
    throw new Error(`unexpected function in calldata: ${decoded.functionName}`);
  }
  return decoded.args[0];
}

function assertCalldataMatches(calldata: `0x${string}`, batch: Batch): void {
  const decoded = decodeDistribute(calldata);
  const matches =
    decoded.length === batch.recipients.length &&
    decoded.every((address, i) => address === batch.recipients[i]);
  if (!matches) {
    throw new Error(
      `batch ${batch.number} calldata does not decode back to its recipients`,
    );
  }
}

/**
 * Bind an approved manifest to a deployed candidate. Pure and deterministic: no I/O, no network,
 * no signing, no mutation of the input manifest, and identical inputs always produce an identical
 * plan. The manifest is re-validated with `parseManifest` first: satisfying the `Manifest` type is
 * not evidence a manifest is genuine, so nothing reaches calldata generation unvalidated.
 */
export function buildDistributionPlan(input: PlanInput): DistributionPlan {
  const manifest = parseManifest(input.manifest);
  const {
    manifestSha256,
    targetChainId,
    token,
    sourceCommit,
    runtimeBytecodeSha256,
  } = input;

  if (!SHA256.test(manifestSha256)) {
    throw new Error("manifestSha256 must look like sha256:<64 lowercase hex>");
  }
  if (!Number.isInteger(targetChainId) || targetChainId <= 0) {
    throw new Error(
      `targetChainId must be a positive integer, got ${targetChainId}`,
    );
  }
  if (typeof token !== "string" || !isAddress(token)) {
    throw new Error(
      `token must be a valid Ethereum address, got ${String(token)}`,
    );
  }
  if (token.toLowerCase() === ZERO_ADDRESS) {
    throw new Error("token must not be the zero address");
  }
  const tokenAddress = getAddress(token) as `0x${string}`;
  if (!GIT_COMMIT.test(sourceCommit)) {
    throw new Error(
      "sourceCommit must be a full 40-character hex git commit SHA",
    );
  }
  if (!SHA256.test(runtimeBytecodeSha256)) {
    throw new Error(
      "runtimeBytecodeSha256 must look like sha256:<64 lowercase hex>",
    );
  }

  const tokenLower = tokenAddress.toLowerCase();
  const batches: PlanBatch[] = splitBatches(manifest).map((batch) => {
    for (const recipient of batch.recipients) {
      // The manifest was approved before the token existed, so this is the first point the token
      // can be excluded from its own recipient list. The contract also rejects it on chain.
      if (recipient.toLowerCase() === tokenLower) {
        throw new Error(
          `batch ${batch.number} contains the deployed token address ${tokenAddress}: the token contract cannot be a recipient`,
        );
      }
    }
    const calldata = encodeDistribute(batch.recipients);
    assertCalldataMatches(calldata, batch);
    return { number: batch.number, recipients: batch.recipients, calldata };
  });

  return {
    version: PLAN_VERSION,
    targetChainId,
    token: tokenAddress,
    sourceCommit,
    runtimeBytecodeSha256,
    manifestSha256,
    batches,
  };
}

/** Deterministic pretty JSON serialization with a trailing newline. */
export function distributionPlanToJson(plan: DistributionPlan): string {
  return `${JSON.stringify(plan, null, 2)}\n`;
}
