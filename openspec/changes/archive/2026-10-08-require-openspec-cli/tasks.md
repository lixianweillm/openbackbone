## 1. Installer

- [x] 1.1 Add `--yes` / `OPENBACKBONE_YES=1` and a terminal prompt that works under `curl | bash`
- [x] 1.2 Add `require_openspec`, called before the first write when the `openspec` component is selected
- [x] 1.3 Make an `openspec init` failure fatal

## 2. Verification

- [x] 2.1 Regression tests: missing CLI fails and changes nothing; `--yes` installs and continues; init failure fails then self-heals
- [x] 2.2 Check the decline path by hand on a pseudo-terminal

## 3. Living documents

- [x] 3.1 README.md and README.zh-CN.md: prerequisite, offer to install, `--yes`
