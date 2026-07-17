.PHONY: help fmt fmt-check lint build test-unit test-fuzz test-invariant test gas coverage \
	audit consistency ops-install ops-check check check-deep clean

help:
	@echo "fmt             Format Solidity and TypeScript"
	@echo "fmt-check       Check Solidity and TypeScript formatting"
	@echo "lint            Lint production Solidity (src and script)"
	@echo "build           Build Solidity and report contract sizes"
	@echo "test-unit       Run the unit test file"
	@echo "test-fuzz       Run the fuzz suite"
	@echo "test-invariant  Run the invariant suite"
	@echo "test            Run the ordinary Forge tests once (excludes the gas suite)"
	@echo "gas             Run only the isolated gas measurements"
	@echo "coverage        Run Forge coverage (excludes the gas suite)"
	@echo "audit           Run Slither static analysis"
	@echo "consistency     Lightweight repository consistency checks"
	@echo "ops-install     Install pinned Bun dependencies"
	@echo "ops-check       Run all Bun validation"
	@echo "check           Run all non-destructive default local checks"
	@echo "check-deep      Run the deep fuzz/invariant profile once"
	@echo "clean           Remove generated Foundry build outputs"

fmt:
	forge fmt
	cd ops && bun run format

fmt-check:
	forge fmt --check
	cd ops && bun run format:check

lint:
	forge lint src script

build:
	forge build --sizes

test-unit:
	forge test --match-path test/MigrateRepV2Token.t.sol

test-fuzz:
	forge test --match-path 'test/fuzz/*.t.sol'

test-invariant:
	forge test --match-path 'test/invariant/*.t.sol'

# Ordinary suite: unit, fuzz, invariant, and deploy-script tests. Excludes the gas suite,
# runs no coverage instrumentation, and does not use the deep profile.
test:
	forge test --no-match-path 'test/gas/*'

# Isolated gas measurements only; -vv surfaces the logged figures.
gas:
	forge test --match-path 'test/gas/*.t.sol' -vv

# Coverage excludes the gas suite and uses the default (non-deep) profile.
coverage:
	forge coverage --no-match-path 'test/gas/*' --no-match-coverage '(test|script)/'

audit:
	slither .

# Fails if any forbidden administrative or economic selector appears in the ABI.
consistency:
	@forge build > /dev/null
	@if forge inspect MigrateRepV2Token methodIdentifiers | \
		grep -qiE '\b(mint|burn|burnFrom|owner|transferOwnership|grantRole|revokeRole|pause|unpause|blacklist|setFee|setTax|enableTrading|enableTransfer|recoverToken|withdraw|upgradeTo|permit|delegate|claim|redeem|transferAndCall|approveAndCall)\b'; then \
		echo "forbidden selector present in ABI"; exit 1; \
	else echo "ABI surface is clean"; fi
	@git diff --check

ops-install:
	cd ops && bun install --frozen-lockfile

ops-check:
	cd ops && bun run check

# Default local gate. Fast and repeatable: no coverage, no gas snapshots, no deep profile,
# no nested check, and no duplicate full Forge run.
check: fmt-check lint build test ops-check audit consistency

# Deep release profile, run once, separately from the default gate.
check-deep:
	FOUNDRY_PROFILE=deep forge test --no-match-path 'test/gas/*'

clean:
	forge clean
