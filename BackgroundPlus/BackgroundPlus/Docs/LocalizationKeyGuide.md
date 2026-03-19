# Localization Key Guide

- Prefix: `btm.<module>.<name>`
- Modules: `list`, `detail`, `delete`, `confirm`, `result`, `error`, `history`
- Keys must be semantic, stable, and shared by zh-Hans/en files.
- Business-facing UI strings must use localization keys; avoid hardcoded literals.
- String formatting placeholders must keep the same order between languages.

## Examples

- `btm.list.title`
- `btm.confirm.dry_run.summary`
- `btm.result.backup.path`
