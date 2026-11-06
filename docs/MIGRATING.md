# Upgrading to Omarchy AI Model Dock 0.12

The project now focuses on preparing and serving local models. The former
always-on Local AI assistant has been removed from the current distribution.
Older versions remain in Git tags for historical inspection.

## Existing Model Dock installs

The repository's canonical URL is now:

    https://github.com/gustavonline/omarchy-ai-model-dock

The manifest ID stays `io.github.gustavonline.local-ai`. Keep the installed
plugin directory in place; changing its folder can break existing CLI/skill
symlinks. GitHub redirects the old repository URL, so an existing Git remote can
still fetch it. Update that remote to the canonical URL when convenient.

User model configuration, keys, weights, reports and client profiles stay outside
the checkout. The model service does not need a restart just for this UI cleanup.
Existing hand-prepared TOML runtime profiles remain usable.

## Retire the old assistant

If the assistant is enabled, stop it before the upgrade:

```bash
systemctl --user disable --now omarchy-local-ai-assistant.service
```

After the plugin update, run its `model-dock install` if the CLI/skill needs
linking, then:

```bash
omarchy-model-dock migrate
```

This command checks ownership before removing the retired assistant's user unit
and its `voice-start`/`voice-stop` Lua bindings. It backs up the originals under
`~/.local/state/omarchy/model-dock/legacy-backups/`. Unrelated services and bindings
are preserved. It refuses to rewrite linked or differently owned integrations.

The original assistant settings, history, local Pi data and the rest of the
TOML file remain on the machine. They are not read by the current model panel.
Review and remove private data separately if you no longer want it.

After changing Hyprland bindings, apply and check the configuration through the
normal session environment:

```bash
hyprctl reload
hyprctl configerrors
```

The removed features are the desktop observer, proactive suggestions, voice
summon UI, playbook/dismissal memory, and heavy-harness delegation. Pi and Codex
remain supported **clients of inference**, not embedded desktop assistants.

## Recovery

The migration backup contains the service file and complete previous bindings.
To return to the old assistant, first check out a pre-0.12 tag that contains its
runtime. Restore only the desired original lines from the backup, preserving
later edits to bindings, then reload/validate the configuration. Restore and
reload the user unit deliberately; do not enable the old observer merely to
restore model serving. Current models and keys need no rollback for this step.
