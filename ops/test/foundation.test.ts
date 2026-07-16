import { expect, test } from "bun:test";
import { isAddress } from "viem";
import { z } from "zod";

const addressSchema = z.string().refine(isAddress, "invalid Ethereum address");

function compareAddresses(left: string, right: string): number {
  const normalizedLeft = left.toLowerCase();
  const normalizedRight = right.toLowerCase();

  if (normalizedLeft < normalizedRight) return -1;
  if (normalizedLeft > normalizedRight) return 1;
  return 0;
}

test("foundation dependencies handle deterministic Ethereum data locally", () => {
  const addresses = [
    addressSchema.parse("0x0000000000000000000000000000000000000002"),
    addressSchema.parse("0x0000000000000000000000000000000000000001"),
  ].sort(compareAddresses);

  const serialized = JSON.stringify({
    addresses,
    rawBalance: 1n.toString(10),
  });

  expect(JSON.parse(serialized)).toEqual({
    addresses: [
      "0x0000000000000000000000000000000000000001",
      "0x0000000000000000000000000000000000000002",
    ],
    rawBalance: "1",
  });
});
