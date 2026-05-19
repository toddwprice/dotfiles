---
description: Run full astro verification (compile, lint, tach, modularity, AGENTS.md compliance)
---

Run the following verification steps for the astro application, in order. Stop and report if any step fails.

All commands should be run from the `apps/astro` directory.

## 1. Compile all astro code

```bash
cd apps/astro && uv run python -m compileall app/ -q
```

## 2. Ruff lint and format check

```bash
cd apps/astro && uv run ruff check --fix . && uv run ruff format .
```

## 3. Tach modularity check

```bash
cd apps/astro && uv run tach check
```

## 4. Modularity check

Run `./bin/sync_modules` and verify no new modules or submodules have been created. Prefer internal packages over new modules.

```bash
cd apps/astro && ./bin/sync_modules
```

If new modules were detected, flag them and ask whether they are intentional.

## 5. Run all astro tests in parallel

```bash
cd apps/astro && uv run pytest -n 4 -m 'not service_level and not axon_integration'
```

## 6. AGENTS.md / CLAUDE.md compliance

Read `apps/astro/AGENTS.md` (or `apps/astro/CLAUDE.md`) and verify that all changes in the current branch follow the rules documented there. Pay particular attention to:

- Test patterns (no patching, prefer service tests, dependency injection)
- Modularity rules (no cross-domain imports in core, use registries)
- Colocated test structure
- Pydantic models for type safety

Report a summary of all steps: passed, failed, or warnings.
