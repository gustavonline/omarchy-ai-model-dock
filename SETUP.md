# Model Dock setup

Model Dock provisions one maintained llama.cpp router as a **systemd user**
service. Each registered GGUF gets a preset; clients choose its model ID. Models
load on demand. No Docker, Python packages or root service are needed.

The current automated serving target is Linux with systemd. The initial hardware
validation is AMD Ryzen AI Max+ 395 / Radeon 8060S (Strix Halo), using Vulkan.
Other platforms are detected but must be measured before claiming equivalent
support. [Mac Studio and MLX tracking](https://github.com/gustavonline/omarchy-llama-cpp-local-ai/issues/13).

## Install

```bash
omarchy plugin add https://github.com/gustavonline/omarchy-llama-cpp-local-ai --enable --yes
```

Click **Set up Model Dock** in the right-hand bar panel. This opens a short
terminal setup, links the CLI and agent skill, offers two small verified starter
models, starts the router and runs authentication and inference checks. Or ask
an agent to read the repository's root `SKILL.md` and do the setup.

Find the plugin by its manifest ID, not a hardcoded checkout folder name. New
installs normally use `~/.config/omarchy/plugins/io.github.gustavonline.local-ai/`;
older clones may still be named `gustav.local-ai`.

```bash
cd /path/to/plugin
./model-dock install
./model-dock inspect
```

A working llama-server is reused. Detection checks its actual device list.
Without a compatible binary, build one from a pinned upstream commit:

```bash
./model-dock build --backend vulkan
```

Build dependencies on Arch/Omarchy include `base-devel`, `cmake`, and for Vulkan
`vulkan-headers`, `vulkan-icd-loader`, `shaderc`, plus the correct GPU driver.
CUDA/HIP need the vendor's supported toolkit and compatible GPU. Missing system
packages require ordinary owner-approved package installation; the plugin does
not install them silently. Builds live in `~/.local/opt/model-dock-llama-BACKEND/`.
A failed build directory is preserved for diagnosis instead of overwritten.

## Agent/noninteractive setup

```bash
./model-dock fetch --starter qwen3-0.6b
./model-dock add --file ~/.local/share/models/model-dock/Qwen3-0.6B-Q8_0.gguf \
  --name qwen3-0.6b --context 4096 --slots 2
./model-dock start
./model-dock check
./model-dock request --model qwen3-0.6b --prompt 'Say hello in Danish.'
./model-dock benchmark --model qwen3-0.6b --clients 2
```

The starters are small, publisher-provided Q8 GGUFs, pinned by commit, size and
SHA-256. They establish compatibility and latency; they are not an endorsement
as the newest or strongest model. `fetch --repository OWNER/REPO --file FILE.gguf`
resolves a requested model to a commit and published SHA-256. Check its license
and model card first. Split files must all be downloaded; register the first one.

## Context, cache and concurrency

`--context` means tokens **per slot**. With 4096 context and 2 slots, llama.cpp
receives 8192 total context. Both slots share one model. Continuous batching
allows overlapping inference. Prefix KV reuse avoids evaluating an unchanged
prompt prefix again; RAM prompt-cache storage defaults to 256 MiB per model. Large hybrid/MTP model
states can exceed that bound; inspect runtime logs instead of assuming cache hits.
Tune `--prompt-cache-mib N` deliberately within available host RAM. This stores
prompt snapshots in RAM; it is separate from the live GPU KV type and context.

```bash
./model-dock tune --model qwen3-0.6b --context 8192 --slots 2 --cache q8_0
./model-dock tune --max-loaded 2
./model-dock restart
```

Restart interrupts requests. Adding/tuning does not restart automatically.
More slots or larger context uses more memory; quantized KV may change quality
and backend compatibility. Start with f16, measure a realistic prompt, and only
then compare q8_0/q4_0. Do not copy speculative decoding or draft-model settings
across architectures without verification.

The router's model count is not a strict memory budget. It unloads idle models
when the configured count is reached; loading a new model may wait or fail when
all capacity is busy. Keep enough memory for the desktop, other services and KV
cache. There is no cross-machine load balancing, tenant isolation, billing or
per-user quota system. Put such requirements in a separate gateway if needed.

`--ubatch-size` sets the physical prompt-processing batch (128–2048, default
512). The logical batch stays at 2048. More batching can improve prefill but uses
additional memory and may be slower on another backend; measure before keeping it.

## Native MTP and client output budgets

For a model whose GGUF includes a compatible MTP head, `tune --model ID
--draft-tokens 3` enables llama.cpp's native MTP speculation. Zero disables it.
This is opt-in: an arbitrary model/build may not support it, and speed/quality
must be tested with the actual client. Recheck prefix-cache behavior and memory;
a faster isolated decode is not automatically a faster agent task.

`client pi --model ID --max-output 4096` sets Pi's per-request output budget in a
separate profile. The default stays 512 for small probes; larger coding outputs
need an explicit budget and enough context headroom. Sampling parameters remain
ordinary private Pi model configuration. No real key is written into examples.

## Service lifecycle

- `start` / `stop`: start/stop this router and its worker processes only.
- `load MODEL` / `unload MODEL`: prepare with a one-token public warm-up/release a model.
- `remove MODEL`: unregister an extra model, retaining its downloaded file.
- `start --autostart`: also start with the user manager after future boots/logins.
- `autostart off`: disable that behavior; does not stop a running server.
- `status`: JSON with readiness, models, endpoint and latest latency report.
- `check`: authenticated discovery plus rejection tests for models, chat, Responses and model loading.

For startup before login, inspect `loginctl show-user "$USER" -p Linger`.
Enabling linger is an explicit owner/system decision. Boot disk encryption,
lid policy, AC/network restrictions and OS updates are outside this plugin.

## Existing Local AI installs and upgrades

The plugin ID and `local-ai-control`, `local-ai-assistant`, existing TOML profiles
and services remain supported. Existing profiles are accessible through the
panel's **Existing runtime profiles** disclosure. They are not automatically
imported, stopped, renamed or rewritten by Model Dock. Avoid running a large
legacy profile alongside the dock without checking memory pressure.

Managed configuration, model files, reports and the key live outside the checkout.
`omarchy plugin update` therefore updates code without replacing these files.
`./model-dock install` is idempotent and keeps unrelated skill/CLI entries intact.
No elevated update hook is needed. Keep the stable plugin directory in place;
if moving it, re-link its user-owned CLI/skills deliberately.

To remove the plugin, first stop the service and disable autostart. Then remove
`omarchy-model-dock.service` from the user's systemd directory and run
`systemctl --user daemon-reload`. Remove only CLI/skill symlinks that point to
this checkout. Configuration, keys, reports and downloaded models are retained
until explicitly deleted by the owner.
