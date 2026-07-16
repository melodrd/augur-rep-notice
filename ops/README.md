# Operations package

Bun is the sole JavaScript package manager for this repository. Node.js remains installed only as a compatibility fallback.

- Do not run repository installs with npm or pnpm.
- Do not create `package-lock.json`, `pnpm-lock.yaml`, or `yarn.lock`.
- CI and reproducible local setup use `bun install --frozen-lockfile`.
- Bun executes TypeScript directly and provides the test runner.
- `tsc --noEmit` performs static type checking; Bun transpilation alone is not type checking.
- Biome performs TypeScript formatting and linting.
- Keep Bun-specific runtime APIs to a minimum for portability.
- No production operational scripts, RPC clients, recipient logic, or migration logic exist yet.

```bash
bun install --frozen-lockfile
bun run check
```
