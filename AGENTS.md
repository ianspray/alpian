# Alpian Agent Guidelines

## License & Copyright
- All new code must use MIT license
- Add SPDX header where language permits
- Copyright line: "Copyright (c) 2026 Ian Spray"
- Do NOT modify license headers of external code (e.g., overlayRoot.sh)

## Project Structure
- `config/*.conf` - Board-specific configuration (Alpine version, kernel repo/branch)
- `boards/<board>/genimage.config` - Partition layout per board
- `scripts/` - Build stage scripts (fetch, uboot, kernel, apk, root, image)
- `initramfs/` - Initramfs components
- `overlayfs/` - Runtime overlayfs scripts

## Adding/Modifying Code
1. Identify the relevant board config or script
2. Make changes following existing code patterns
3. Run appropriate build stage to test (or describe testing in plan)
4. Commit changes

## Git Workflow

**For fixes and incremental improvements:**
1. `git add -A` - Stage all changes
2. `git commit -m "<type>(<scope>): <subject>"` - Commit to local main branch
3. Follow [Conventional Commits](https://www.conventionalcommits.org/) format:
   - `feat`: New feature
   - `fix`: Bug fix
   - `docs`: Documentation
   - `style`: Code style changes
   - `refactor`: Code refactoring
   - `test`: Test updates
   - `chore`: Build/tooling changes

**For large refactoring or new approaches:**
- Ask the user first before committing if they want to use main or a feature branch
- Describe the proposed changes and rationale
- Wait for approval before proceeding

## Pre-commit Checklist

1. **Locally generated files** - Ensure SPDX header and "Copyright (c) 2026 Ian Spray" are present
2. **External files** - Add reference comment noting original license (e.g., "Derived from X, original license: Y")
3. **No license modification** - Do not alter existing license headers of external code

## Adding a New Board
1. Create `config/<board>.conf` with ALPINE_VERSION, KERNEL_REPO, KERNEL_BRANCH
2. Create `boards/<board>/genimage.config` with partition layout
3. Create `scripts/fetch/<board>.sh` to source common.sh
4. Add board to BOARDS list in Makefile

## Build Process
- All builds run inside containers (Docker/Podman)
- Use `make container-run` to enter build environment
- Board config loaded automatically via BOARD variable

## Testing
- Describe testing approach in implementation plans
- Prefer verifying build stages complete successfully
- If the user reports issues that are not in the local tree, assume they are building elsewhere and ask for relevant logs to help determine the failure
