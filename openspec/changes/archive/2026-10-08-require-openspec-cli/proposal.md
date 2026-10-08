## Why

openbackbone is OpenSpec plus more, so an installation without the OpenSpec CLI is not a working installation. Today the installer skips the `openspec` component, installs the rest, and reports success, leaving a project with rules and skills that point at a workflow it cannot run.

## Roadmap

Unplanned: requested by the maintainer after the first release.

## What Changes

- **BREAKING** When the `openspec` component is selected and the OpenSpec CLI is missing, the installer no longer skips the component. It stops before writing any file unless the CLI gets installed.
- In an interactive shell the installer offers to install the CLI with npm. `--yes` (or `OPENBACKBONE_YES=1`) accepts the offer without asking.
- If the user declines, there is no terminal to ask on, npm is missing, or `openspec init` fails, the installer exits with an error.
- Skipping with a remedy remains only for the `hooks` component.

## Capabilities

### New Capabilities

### Modified Capabilities
- `workflow-installation`: the OpenSpec CLI becomes a hard prerequisite of the `openspec` component; "Skipped components are reported" is replaced by a hooks-only requirement.

## Impact

`init.sh` (prerequisite check, new `--yes` option, `openspec init` failure handling), `scripts/regression-test.sh`, both READMEs.
