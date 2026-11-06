# Releasing Model Dock

1. Keep the manifest, changelog and current product name consistent.
2. Run `./test.sh` on Linux with Python 3.11+, jq and the native plugin validator.
3. Load the actual QML component with the current Omarchy shell modules. Check
   setup, model selection, keyboard focus, loading/error feedback, copy actions,
   start/stop and existing runtime compatibility. A locked desktop can limit
   physical interaction checks; record that limit rather than bypassing it.
4. Exercise an authenticated real request and missing-key rejection. For runtime
   changes, repeat only the affected inference/cache/concurrency checks.
5. Keep private config, keys, host/network identities, weights and raw personal
   prompts out of source and release artifacts.
6. Verify upgrade behavior, CLI/skill links and configuration preservation.
   Release 0.12 also needs the owned assistant-retirement migration checked.
7. Publish the reviewed commit and matching version tag, then verify CI and the
   installed revision. Source publication is separate from any Resources release.

Keep hardware-specific measurements dated with their exact settings and limits.
The native preview uses illustrative state, not evidence of desktop interaction.
