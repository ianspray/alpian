# Repository Guidelines

## Project Structure & Module Organization
This repository is currently a clean slate with no tracked files. As you add code, keep a predictable layout:
- `src/` for application or library source.
- `tests/` for automated tests (unit/integration).
- `assets/` for static files (images, fixtures, sample data).
- `scripts/` for developer utilities (build, lint, release).
If you introduce a different structure, document it here and keep it consistent.

## Build, Test, and Development Commands
No build or test commands are defined yet. When you add tooling, list the exact commands here with one-line intent, for example:
- `npm run dev` to start a local development server.
- `npm test` to run the full test suite.
- `make build` to create production artifacts.
Keep commands stable and avoid hidden side effects.

## Coding Style & Naming Conventions
Until a formatter or linter is added, use these defaults:
- Indentation: 2 spaces for JS/TS, 4 spaces for Python, tabs only for Makefiles.
- Filenames: `kebab-case` for directories, `PascalCase` for components/classes, `snake_case` for Python modules.
- Prefer explicit names over abbreviations (e.g., `user_session` not `usr_sess`).
When you introduce tools like Prettier, ESLint, Black, or Ruff, document the versions and how to run them.

## Testing Guidelines
There is no testing framework configured yet. When you add tests:
- Name test files with a clear suffix (e.g., `*.test.ts`, `test_*.py`).
- Keep tests close to the code they cover or in a parallel `tests/` tree.
- Include basic smoke tests for new features.
Document coverage expectations (e.g., minimum 80%) and how to run fast vs full suites.

## Commit & Pull Request Guidelines
There is no commit history to derive conventions from. Adopt a simple, consistent pattern:
- Commit messages: `type(scope): summary` (e.g., `feat(api): add user lookup`).
- Pull requests: include a short description, linked issue (if any), test results, and screenshots for UI changes.
- Use the branch `main` when creating a fresh repository
- After every clean build, check in the changes 
- Ensure there is a detailed summary in the body of the commit message
Keep PRs focused and avoid unrelated refactors.

## Security & Configuration Tips
Store secrets in environment variables, not in the repo. Add a `.env.example` file when configuration is required, and document required variables here. Avoid committing credentials or private keys.
