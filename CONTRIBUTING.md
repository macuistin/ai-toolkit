# Contributing

Thanks for helping. Keep changes small and explain the reason in the pull request.

## Before you open a pull request

1. Run the public-safety scan with your own term list, kept outside the repo:
   ```bash
   DENYLIST_FILE=/path/to/your/terms.txt tools/check-public.sh
   ```
   The script fails if any listed term or secret-like token appears in a tracked file.
2. Check that every `.json` file parses, and that each Markdown file has balanced code fences. CI runs both checks.
3. Validate the plugin with `claude plugin validate ./`.

## What to leave out

- Personal details, employer names and internal system names, in code, examples or screenshots.
- Real config files. Only `config/sources.example.json` belongs in the repo.
- Generated output, logs and snapshots.

## Plugin conventions

- Each skill is a folder with a `SKILL.md`. Shared rules live in `references/shared.md`.
- Describe what a skill needs ("list events in a range") rather than naming one vendor's tool, so it works with any connector.
- Skills that send, delete or change external data must ask first.
