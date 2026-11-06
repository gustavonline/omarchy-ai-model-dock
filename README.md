# Omarchy Model Dock

Local inference, ready to connect. A native Omarchy panel for people, a small CLI
and bundled skill for agents, and llama.cpp underneath.

Model Dock examines the machine, reuses a compatible runtime, verifies model
downloads and serves named models behind a private, authenticated endpoint.
The right-hand bar panel stays simple: a numbered model hotbar, start/stop, copy
its endpoint or open setup. Press 1–5 while the panel is open to prepare a model. Your agent handles model selection and tuning.

## Get started

```bash
omarchy plugin add https://github.com/gustavonline/omarchy-llama-cpp-local-ai --enable --yes
```

Click **Set up Model Dock**, or ask your agent to read the root
[SKILL.md](SKILL.md) and configure it. New users can try a short terminal wizard;
agents use the same noninteractive commands. See [setup](SETUP.md).

The plugin was previously called Local AI. Its repository URL and manifest ID
stay the same, so existing installations can update normally. Old runtime
profiles and the optional assistant are retained.

## What it handles

- Actual OS, build, memory and accelerator inspection.
- Pinned, SHA-256-verified GGUF downloads and private per-model configuration.
- One systemd user service with llama.cpp’s native model router.
- Multiple model IDs, lazy loading and a configurable number of resident models.
- Per-model context and parallel slots, continuous batching and prefix caching.
- Measurements of first visible token, warm-prefix reuse and concurrent requests.
- Loopback-only inference with a private API key and SSH access from other networks.
- A discoverable agent skill and CLI that stay usable after plugin updates.

The first verified GPU platform is **AMD Strix Halo / Radeon 8060S on Linux with
Vulkan**. CPU builds are supported by the provisioning command. Other builds are
hardware-dependent; detection is not a benchmark. MLX/Metal and a future Mac
Studio are [tracked separately](https://github.com/gustavonline/omarchy-llama-cpp-local-ai/issues/13).

## Daily use

```bash
omarchy-model-dock inspect
omarchy-model-dock status
omarchy-model-dock start
omarchy-model-dock load qwen3-1.7b
omarchy-model-dock request --model qwen3-1.7b --prompt 'Say hello in Danish.'
omarchy-model-dock benchmark --model qwen3-1.7b --clients 2
omarchy-model-dock stop
```

Names here are small infrastructure-test starters, not promises about the best
current model. Ask an agent to choose a publisher, model and quantization for
your actual work, then test that work.

Start-at-login is opt-in: `start --autostart`. Before-login startup requires an
already persistent systemd user manager; boot encryption is separate. See
[service and tuning details](SETUP.md).

## Remote clients

Use the same API from Python or a compatible agent client. SSH forwards the
endpoint securely from another machine; the runtime never binds a public port.
The API key is read from a private file and is never copied by the bar widget.
See [client setup and limitations](docs/CLIENTS.md).

This is a private inference server for trusted users. It provides model routing
and batching on one machine. Cluster load balancing, per-tenant quotas and
untrusted public API hosting need a separate gateway. API compatibility also
does not guarantee that a particular model can complete a coding-agent task.

## Existing features

Existing `local-ai-control` profiles remain accessible from **Existing runtime
profiles**. Their services and configuration are not rewritten or stopped.
The optional local Pi assistant, voice workflow and approved harness handoffs
remain available; read the [assistant guide](docs/ASSISTANT.md).

## Development

```bash
./test.sh
```

The tests cover existing runtime/assistant behavior plus Model Dock’s downloads,
credential handling and service boundaries. Live inference results and limits
are recorded in [Z13 validation](docs/Z13-VALIDATION.md).

User settings, model files and secrets live outside the checkout. The plugin
uses native shell components and theme tokens, without modifying Omarchy’s
system files. Updates still require validation against the installed shell and
runtime versions; see [releasing](RELEASING.md).

The [Qwen 3.8 27B / 64K follow-up](docs/QWEN38-Z13.md) includes real Pi coding work,
long-prefix reuse and measured cache/draft/batch settings on Z13.
