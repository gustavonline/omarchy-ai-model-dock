# Release checklist

1. Update `manifest.json` and `CHANGELOG.md` to the same semantic version.
2. Run `./test.sh` on a current Omarchy installation.
3. Install from a fresh clone and verify missing-config, ready-profile, start,
   switch, restart, stop, endpoint copy, Assistant setup/enable/pause/disable,
   suggestion-card actions, and error-display behavior.
4. Confirm the repository contains no models, API keys, local TOML files,
   machine-specific services, Assistant settings/playbooks, or hardware tuning.
5. Merge to `main`, tag the manifest version (for example `v0.11.0`), and create a
   GitHub Release from the matching changelog section.

Model Dock also needs a clean user-directory install, pinned download integrity,
unauthenticated rejection, concurrent inference, two-model routing, stop/restart
and an upgrade check that preserves keys and configuration. Record exact hardware
and limits. Distinguish automated tests, live protocol tests and full agent-task
quality. Never publish private config, keys, network identifiers or raw benchmark
paths. The native control preview uses illustrative data.
