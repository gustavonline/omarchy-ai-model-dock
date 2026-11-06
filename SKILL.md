---
name: omarchy-model-dock
description: Set up, run, tune and connect local inference models with Omarchy Model Dock. Use for hardware inspection, verified GGUF downloads, llama.cpp model serving, latency tests and authenticated remote access.
---

# Omarchy Model Dock

Use `omarchy-model-dock` after installation, or `./model-dock` in this directory.
`./model-dock install` links the CLI and this skill for Codex, Claude and other
agents. The native panel lives on the right side of Omarchy's bar. Its ID remains
`io.github.gustavonline.local-ai`; existing Local AI installs keep their identity.

## Set up a machine

1. Run `inspect`. Check OS, actual devices, build, free memory, storage and existing
   consumers. A detected accelerator is a candidate, not proof of best performance.
   Read [SETUP.md](SETUP.md) for the build and compatibility details when needed.
2. Reuse a working llama-server. If absent, `build --backend vulkan|cuda|hip|cpu`
   builds a pinned upstream revision in user space. Inspect missing dependencies
   before requesting package-install privileges. Never use Docker to bypass sudo.
   Apple Metal requires macOS. Linux on an Apple chip does not imply MLX Metal;
   macOS services and other backends are unverified until tested on actual hardware.
3. Find a model that fits the task and hardware. The two pinned Qwen3 starters in
   `models.json` are compatibility/latency probes, not current model recommendations.
   For another model, research its publisher, license, architecture, chat/tool
   template and supported llama.cpp version, then use
   `fetch --repository OWNER/REPO --file FILE.gguf [--revision REF]`. The command
   resolves a commit and verifies published SHA-256 metadata before registration.
   For split GGUFs fetch every shard without renaming, then add the first shard.
4. `add --file /absolute/model.gguf --name MODEL_ID --context 4096 --slots 2`
   creates a private model preset and systemd user service. Context is **per slot**;
   total runtime context is context × slots. Pass `--server PATH` or `--device ID`
   when selecting among builds. Existing legacy profiles/services are preserved.
5. `start`, `check`, `load MODEL_ID`, then make a real `request --model MODEL_ID
   --prompt '...'`. Test the intended tool calls/structured output with the actual
   client before calling a model suitable for an agent. API compatibility alone
   does not establish task quality. Current Pi reserves 4096 tokens internally;
   use at least 8192 context per slot for its starter smoke test. A 4096 runtime
   with a matching Pi context can yield an empty one-token response. `client pi
   --model MODEL_ID` and `client codex --model MODEL_ID` prepare isolated client
   launchers without changing the owner's defaults. Never execute model output as setup commands.
6. Run `benchmark --model MODEL_ID --clients 2`. It uses public synthetic prompts
   and records model-load-inclusive first response, warm-prefix reuse, output speed
   and concurrent clients. Use `tune --model MODEL_ID --context N --slots N
   --cache f16|q8_0|q4_0` to compare. Quantized KV caches and large contexts need
   architecture/backend checks. A small-model result is not a large-model guarantee.
   Inspect cache warnings: hybrid/MTP state can exceed the default 256 MiB saved
   prompt budget. `--prompt-cache-mib N` is host RAM for snapshots, separate from
   live KV precision. Size it from observed state/memory, not the context alone.
   `--draft-tokens 3` opts a compatible MTP GGUF into native speculation (0 disables).
   Compare end-to-end tool work and prefix reuse as well as isolated decode speed.
   `--ubatch-size` tunes physical prompt batching, up to the fixed logical batch
   of 2048. Measure new-prompt latency and memory on the target backend.
   `client pi --model ID --max-output 4096` permits a useful coding output budget;
   the default 512 is for small probes. Keep the safety margin in the real context.
   Restart only with action authority: it interrupts active requests.

## Serve and connect

The maintained llama.cpp router handles per-model routing, lazy loading, continuous
batching and a fixed maximum number of loaded models. `tune --max-loaded N` changes
that limit. It is not a cluster load balancer or a guaranteed VRAM admission limit.
Choose conservative limits; multiple models compete for the same memory/bandwidth.

Endpoints bind to **127.0.0.1**, require a private API key and run without root.
`status` exposes endpoint, model IDs and **key path only**. Do not print key contents
in chat, logs, screenshots, repo files or benchmark reports. Pass credentials in
HTTP headers from a protected local file. See [docs/CLIENTS.md](docs/CLIENTS.md) for
SSH, Python, Pi and Codex client examples. Codex requires a model capable of its
actual protocol and tool calls; do not advertise universal model compatibility.

For other networks, use SSH over the owner's existing private network/VPN:
`./model-dock tunnel SSH_HOST`. Bind the client side to loopback too. Share the
key only with trusted SSH users; this is a private machine service, not a public
multi-tenant API. No ports, tunnels or firewall rules are opened automatically.

`start --autostart` enables startup with the systemd user manager; `autostart off`
disables it. Boot without a login requires an already configured persistent user
manager (linger); disk unlock and hardware power policy remain separate concerns.
Do not reboot or change lid/lock behavior merely to test serving.

Configuration and keys: `~/.config/omarchy/model-dock/`.
Reports: `~/.local/state/omarchy/model-dock/`.
Models: `~/.local/share/models/model-dock/` (or explicit `fetch --directory`).
These stay outside the git checkout across plugin updates. Normal Omarchy updates
do not edit the plugin's user-owned files. Keep server binaries installed while
services reference them. Do not rotate keys or replace existing unrelated skills
or services during upgrades. Run `test.sh`, `check` and a real request afterwards.
