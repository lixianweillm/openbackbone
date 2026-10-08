# Record ownership inside each managed file

- Date: 2026-10-08
- Supersedes: —

The installer replaces skills, schemas, and the ADR rules file on every run, so it has to tell its own files from a project's file of the same name. Each managed file carries a `managed-by: openbackbone` line, and the installer replaces only files that have it. Listing owned paths in `.openbackbone.yaml` would have kept the files clean, but a clone without the manifest would silently stop receiving upgrades, and a project could not take over one file while leaving the rest managed. With the line in the file, deleting it hands that file to the project. The price is a line of installer bookkeeping inside files people read.
