# Connecting clients

The endpoint is `http://127.0.0.1:8090/v1` by default. Model IDs are listed by
`omarchy-model-dock status`. The API key is in
`~/.config/omarchy/model-dock/api-key` (mode 0600). The panel copies only the URL.

## Another machine or network

Use your existing SSH connection, including Tailscale/VPN when needed:

```bash
ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
  -L 127.0.0.1:8090:127.0.0.1:8090 YOUR_SSH_HOST
```

The repository's `model-dock tunnel YOUR_SSH_HOST` runs the same forwarding.
Choose `--local-port` if 8090 is busy. The model server still listens only on its
own loopback interface. SSH encrypts traffic across the network.

Copy the key through SSH into a private client file. Run these on the client,
substituting your SSH host and a private destination you control:

```bash
mkdir -p ~/.config/model-dock
chmod 700 ~/.config/model-dock
scp YOUR_SSH_HOST:.config/omarchy/model-dock/api-key ~/.config/model-dock/api-key
chmod 600 ~/.config/model-dock/api-key
```

Keep it out of chat, source control, command arguments, screenshots and logs.
Only trusted people with access to this SSH connection should receive it. The
runtime's one key also grants authenticated model-management routes; this is
not a public multi-tenant gateway. Neither key auth nor a VPN makes arbitrary
public exposure appropriate. No firewall or public ingress is configured here.

## Python, without another runtime dependency

```python
import json
from pathlib import Path
from urllib.request import Request, urlopen

key = Path.home().joinpath('.config/model-dock/api-key').read_text().strip()
payload = {
    'model': 'qwen3-1.7b',
    'messages': [{'role': 'user', 'content': 'Say hello in Danish.'}],
    'max_tokens': 128,
    'chat_template_kwargs': {'enable_thinking': False},
}
request = Request('http://127.0.0.1:8090/v1/chat/completions',
                  data=json.dumps(payload).encode(),
                  headers={'Content-Type': 'application/json',
                           'Authorization': 'Bearer ' + key})
with urlopen(request, timeout=120) as response:
    print(json.load(response)['choices'][0]['message']['content'])
```

On the server itself, read `.config/omarchy/model-dock/api-key` instead. A model
may need different reasoning/template parameters; check its model card.

## Generate a separate client profile

On the server, after choosing a model with at least 8192 tokens per slot:

```bash
omarchy-model-dock client pi --model qwen3-1.7b
omarchy-model-dock client codex --model qwen3-1.7b
```

Each command returns a private launcher path under the plugin's state directory.
The launcher selects the local provider without replacing your normal client
configuration, and reads the key from its protected file. Pi uses a separate
agent directory; Codex uses a separate configuration home. Additional command
arguments can be passed to the launcher. For clients on another machine, use
the tunnel and protected key copy above, then adapt the explicit templates below.
Codex generation prepares the connection; a complete coding task remains a
separate quality/compatibility test.

## Pi

Merge a provider into your private Pi `models.json` (do not replace existing
providers). The credential command reads the private file at request time:

```json
{
  "providers": {
    "model-dock": {
      "baseUrl": "http://127.0.0.1:8090/v1",
      "api": "openai-completions",
      "apiKey": "!cat ~/.config/model-dock/api-key",
      "models": [{
        "id": "qwen3-1.7b",
        "name": "Model Dock / Qwen3 1.7B",
        "reasoning": false,
        "compat": {"maxTokensField": "max_tokens", "supportsDeveloperRole": false},
        "samplingParams": {"chat_template_kwargs": {"enable_thinking": false}},
        "input": ["text"],
        "contextWindow": 8192,
        "maxTokens": 512,
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0}
      }]
    }
  }
}
```

Set contextWindow/maxTokens to the registered model's actual limits. Current Pi
keeps a 4096-token safety margin when calculating output room, so a 4096-token
model context can produce a one-token/empty answer. Configure at least 8192 per
slot for this small test; substantial coding tasks may need more. Do not merely
increase the client number without increasing and testing the runtime context. Select
`pi --provider model-dock --model qwen3-1.7b`. For the server itself, use its
`.config/omarchy/model-dock/api-key` path. Keep credential commands private and
only load configuration you trust. See the maintained [Pi models guide](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md).

## Codex

A private custom-provider configuration can point to the same endpoint:

```toml
model = "qwen3-1.7b"
model_provider = "model-dock"

[model_providers.model-dock]
name = "Model Dock"
base_url = "http://127.0.0.1:8090/v1"
wire_api = "responses"
env_key = "MODEL_DOCK_API_KEY"
supports_websockets = false
```

Supply `MODEL_DOCK_API_KEY` through a private launcher/credential mechanism that
reads the protected file; never use a literal key in the TOML or a command-line
argument. Prefer a separate client profile to replacing your existing default.
See the official [Codex configuration reference](https://developers.openai.com/codex/config-reference/).

Codex requires the Responses protocol and functional tool calls. Recent
llama.cpp offers a Responses route, but usable support depends on both model
and runtime version. Run a bounded agent task and verify function-call arguments
and follow-up responses before trusting a model with work. A successful chat
request does not prove agent compatibility. The tiny starters are infrastructure
test models and may need larger context for an agent's system prompt.

This plugin does not overwrite existing client credentials or change your
default cloud/local provider.

For larger coding tasks, `client pi --model MODEL --max-output 4096` avoids
the small-probe default of 512 output tokens. The [Qwen 3.8 follow-up](QWEN38-Z13.md)
records a tested 64K model profile and task-specific sampling.
