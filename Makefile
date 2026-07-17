.PHONY: help fmt fmt-check build test gas coverage audit ops-install ops-check check clean

help:
	@echo "fmt          Format Solidity and TypeScript"
	@echo "fmt-check    Check Solidity and TypeScript formatting"
	@echo "build        Build Solidity and report contract sizes"
	@echo "test         Run Forge and Bun tests"
	@echo "gas          Run the Forge gas report"
	@echo "coverage     Run Forge coverage"
	@echo "audit        Run Slither static analysis"
	@echo "ops-install  Install pinned Bun dependencies"
	@echo "ops-check    Run all Bun validation"
	@echo "check        Run all non-destructive local checks"
	@echo "clean        Remove generated Foundry build outputs"

fmt:
	forge fmt
	cd ops && bun run format

fmt-check:
	forge fmt --check
	cd ops && bun run format:check

build:
	forge build --sizes

test:
	forge test
	cd ops && bun test

gas:
	forge test --gas-report

coverage:
	forge coverage

audit:
	slither .

ops-install:
	cd ops && bun install --frozen-lockfile

ops-check:
	cd ops && bun run check

check: fmt-check build test coverage audit ops-check

clean:
	forge clean
