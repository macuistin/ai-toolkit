# Vault helper scripts

Copy this folder into the vault as `_scripts/`. The skills call `$V/_scripts/vq.py` and `$V/_scripts/tagger.py`.

- `vq.py`: read-only tag lookup. `python3 _scripts/vq.py find <tags> [--since 14d] [--grep RE]`, plus `related`, `info` and `tags`.
- `tagger.py`: writes namespaced frontmatter tags to notes. Run `python3 _scripts/tagger.py run --paths <files>`.
- `tag-rules.json`: generic rules. Add your own projects, topics and people here. Set `owner_slug` to your name in lowercase with hyphens so you are not tagged as a person in every note.

Set `SECOND_BRAIN_PATH` to the vault folder. Without it, the scripts look for a `MEMORY.md` next to them.
