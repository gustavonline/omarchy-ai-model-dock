# Qwen 3.8 27B on Z13 — 6 November 2026

A text-only 64K serving profile and actual Pi coding task were tested on the
Ryzen AI Max+ 395 / Radeon 8060S, Omarchy 4.0.6, Vulkan build `b81c99b`.

## Artifact and deployment

The existing local Ollama `qwen3.8:27b` GGUF was reused through an independent
copy-on-write file; no new model download and no changes to Ollama were needed.
The 16,810,714,464-byte Q4_K_M file was verified as SHA-256
`f5f1dd8920d417aac2718b0bda3403da274301efdd6760b4f0f4b864ff2ad57d`.
GGUF metadata reports the `qwen35` architecture and one next-token/MTP layer.
The existing vision projector was not attached; this profile serves text.

Model ID: `qwen3.8-27b`, the third registered hotbar model. The existing small
models remain registered; the router's resident-model cap is still two.
There was no root access, reboot, OS upgrade or public network exposure.

The older Flash Next artifact is around 88 GiB of weights. It was not loaded
into the shared workstation as part of this test.

## What the latency numbers mean

New prompt processing and generated output are different workloads. Prefix reuse
can avoid most repeated prompt processing, but it does not eliminate generation
cost or make previously unseen long input cheap.

| Probe | Observed result |
| --- | --- |
| Short structured answer, no MTP | about 12 output tokens/s |
| Same short probe, MTP draft length 3 | about 22 output tokens/s |
| 12K new prompt, no MTP | 77.2 s to first visible answer |
| Same 12K prefix reused | 0.18 s to first visible answer; 12,059 tokens reused |
| 60,063 new prompt tokens, MTP 3 / F16 / physical batch 512 | 648.1 s to first answer; about 92.7 prompt tokens/s |
| Repeated 60K prompt | 0.407 s to first answer; 60,059 tokens reused, 4 newly evaluated |

The long-input test retrieved an exact marker from synthetic inventory text.
Both new and repeated runs were correct. Input plus output fit within the
65,536-token slot. Agent clients still need output and safety-margin headroom.
The input test is deliberately much larger than an ordinary short conversation.

### Cache and prompt batches

Some saved hybrid/MTP prompt states exceeded the old fixed 256 MiB RAM cache
budget, and the runtime logged that it skipped saving them. This profile was
given a 12,288 MiB host-RAM prompt-state budget. The limit is a cap, not an
up-front reservation. Do not apply it blindly to machines with less memory.
Live GPU KV precision, saved host-RAM state, context, and prompt batching are
separate settings.

With the same 4K synthetic input and MTP 3, F16 and Q8 KV prefill were very close:
roughly 171 versus 175 prompt tokens/s. F16 was retained for precision and the
available memory headroom. At the end of the long test, roughly 59 GiB remained
available. These are short observations, not a memory-capacity guarantee.

Physical batch comparisons on 4K input:

| Physical batch | First answer | Prompt tokens/s |
| --- | --- | --- |
| 512 | 24.36 s | 170.8 |
| 1024 | 26.41 s | 157.7 |
| 2048 | 27.95 s | 149.0 |

Larger batches did not help this build/device/probe. Logical batch remained
2048 throughout; the selected physical batch remains 512. An earlier 4K probe
with overlapping Mac traffic was excluded from this comparison.

### Draft length on generated Python code

A separate code-generation prompt measured observed output tokens divided by
wall-clock decode time (rather than only the runtime's internal counter):

| Draft length | New-prompt output rate | Warm-prefix output rate |
| --- | --- | --- |
| 3 | 22.14 tokens/s | 22.25 tokens/s |
| 4 | 24.08 tokens/s | 26.27 tokens/s |

The responses had slightly different lengths/content, so this is a practical
sample, not a statistically controlled throughput ranking. Four draft tokens
were also present in the owner's older 64K Ollama profiles. The selected
interactive profile uses four; near-full-window validation above used three.

## Real Pi coding task

The model repaired a deliberately broken standard-library CSV parser, using
Pi 1.3.0 and actual read/edit/write/bash tools. It had to handle quoting, embedded
newlines, BOM/header validation and row-width/blank-record edge cases. The source
and private Pi state were writable in a disposable user-service sandbox; the
home/system and supplied tests were read-only. Tests were checked again outside
Pi and confirmed unchanged. [Reproducible task](benchmarks/qwen38/fixture/README.md).

| Configuration | Outcome | Total time |
| --- | --- | --- |
| Non-thinking, temperature 0.7, presence penalty 1.5 | 11/13 tests; hit five-minute limit | 300 s |
| Non-thinking, temperature 0.2, presence penalty 0, seed 7 | 13/13 tests | 138.32 s |
| Same conservative sampling, MTP 3 and larger saved-state budget | 13/13 tests | 114.54 s |
| Same conservative sampling, MTP 4 and larger saved-state budget | 13/13 tests | 80.53 s |

The last three attempts passed. There was one run of each configuration;
this does not prove a universal sampling optimum, and MTP/cache changes were
combined in the final agent run. Native speculative decoding can also change
batch-level numerical behavior. Keep representative task verification.

Pi was also run on a Mac against the Z13 through an authenticated SSH tunnel.
The existing Mac Pi client (1.0.4) returned a real response. No Mac app or new
remote-control service was built. The native Linux hotbar remains on Z13;
a per-owner Terminal launcher can prepare the model and connect existing clients.
A screenshot in a chat remains a preview.

## Reuse

```bash
omarchy-model-dock tune --model qwen3.8-27b --context 65536 --slots 1 \
  --cache f16 --prompt-cache-mib 12288 --ubatch-size 512 --draft-tokens 4
omarchy-model-dock restart
omarchy-model-dock client pi --model qwen3.8-27b --max-output 4096
```

For this task, the private Pi model config used temperature 0.2, top_p 0.8,
top_k 20, min_p 0, presence_penalty 0, repetition_penalty 1, seed 7 and
`chat_template_kwargs.enable_thinking = false`. Thinking tasks may need a
different budget and sampling; this trial does not qualify all tasks or Codex.

The [publisher model card](https://huggingface.co/Qwen/Qwen3.8-27B) describes
thinking controls and MTP. Saved-state behavior and performance here are observed
on this exact llama.cpp build; different runtimes/hardware require measurement.
[Sanitized probe and coding-task reports](benchmarks/qwen38/).
