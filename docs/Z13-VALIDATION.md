# Z13 validation — 6 November 2026

Hardware: Ryzen AI Max+ 395 / Radeon 8060S (Strix Halo), 128 GB nominal shared
memory; Omarchy 4.0.6, Linux x86_64. GPU inference used the existing Vulkan build
at llama.cpp commit `b81c99b`. A fresh CPU build of pinned upstream commit
`52c9bad94678485e82362331cb62b4f71fd3f0e6` also built and answered a real request.
This validates the CPU bootstrap on this Linux host, not every GPU build path.

## Observed behavior

- Official Qwen3 0.6B and 1.7B Q8 GGUFs downloaded and verified against their
  pinned commits, sizes and SHA-256 hashes.
- Both models loaded and answered through the same authenticated router.
- Two simultaneous requests per model succeeded; four clients also completed
  through two slots, with the additional requests queued by the runtime.
- With a one-model limit, preparing the second model evicted the idle first
  model. With a two-model limit, both models remained available together.
- The `load` command uses a one-token public warm-up via normal inference:
  explicit `/models/load` in the existing build rejects a full model limit,
  whereas the inference route applies native LRU eviction.
- An SSH tunnel from a Mac carried authenticated requests to both models on
  the Z13, including concurrent requests to different models. No public bind.
- Missing-key requests were rejected with 401 on model discovery, chat,
  Responses and model loading. Keys stayed in private files/HTTP headers.
- Qwen3 1.7B returned a valid synthetic `add_numbers(a=17, b=25)` tool call.
  The Responses endpoint completed a small text request. No model-generated
  command was executed.
- The installed Pi 1.3.0 client completed a tool-less text request with an
  isolated provider profile. Pi's 4096-token safety margin explains why a 4K
  context yielded an empty/one-token response. Matching 8K runtime/client
  context worked; the CLI rejects smaller agent-client profiles.
- Stop/restart and configuration changes preserved the key. The service also
  passed live inference with read-only home/system protection, private temp,
  protected SSH/cloud directories and no built-in agent/MCP proxy tools.
- Existing legacy profiles and services were not rewritten. Existing runtime
  and Assistant tests passed, along with ten new boundary tests.

## Latency measurements

Public synthetic common prefix: 759 input tokens; deterministic short list
response; streaming and local loopback. Numbers describe these probes, not a
quality evaluation or a sustained production benchmark.

| Probe | First uncached response | Warm first visible token | Warm output rate |
| --- | --- | --- | --- |
| Qwen3 0.6B Q8, 4K/slot, F16 KV | 1.085 s including model load | 0.011–0.012 s | ~211–215 tokens/s |
| Qwen3 1.7B Q8, 4K/slot, F16 KV | 1.034 s including model load | 0.019–0.021 s | ~97–98 tokens/s |
| Qwen3 1.7B Q8, 8K/slot, F16 KV | 0.256 s, already resident | 0.020 s | ~97 tokens/s |

The warm requests reused 758 prefix tokens and evaluated one new prompt token.
The final four-client probe had first visible tokens at roughly 0.254–0.518 s,
including queueing. [Sanitized raw report](benchmarks/z13-qwen3-1.7b-f16.json).

Q8 KV also worked at 8K per slot. A short probe showed no clear latency advantage;
F16 remains the default. This was not a controlled quality or long-context
comparison, so it does not establish the best KV quantization.

## Native panel and release checks

The actual native control component was rendered using the installed Omarchy
Ui/Commons modules with illustrative data. The full plugin loaded successfully
in a separate, hidden Quickshell QA instance. It uses theme colors, native
square controls, a numbered model hotbar, keyboard selection and a loading pulse.

The owner's graphical session was locked. It was not unlocked or restarted to
test the panel. The existing refresh-after-normal-unlock mechanism can load the
updated production widget on the next owner unlock. Physical pointer/keyboard
acceptance in the live desktop remains to be checked there.

No reboot, OS upgrade, broad sudo access, external bind, firewall change or
cloud inference was used. Autostart remains opt-in; the test server was left
running with the two small models and a two-model resident limit.

## Still unverified

- Full Codex coding-task quality and longer Pi tool workflows.
- Large model capacity/latency, long contexts and sustained multi-user load.
- CUDA/HIP/Vulkan bootstrap across fresh machines with different drivers.
- macOS service lifecycle, MLX and Apple Linux GPU performance: [issue #13](https://github.com/gustavonline/omarchy-llama-cpp-local-ai/issues/13).
- Future Omarchy/llama.cpp versions. User-owned paths and native APIs reduce
  update coupling; they are not a promise of compatibility with every update.

Qwen 3.8 27B and near-full 64K input were subsequently qualified in the
[dated follow-up](QWEN38-Z13.md); the limits above describe the initial small-model release.
