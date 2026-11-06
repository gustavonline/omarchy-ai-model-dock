#!/usr/bin/env bash
set -euo pipefail

plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

jq -e '
  .schemaVersion == 1 and
  .id == "io.github.gustavonline.local-ai" and
  .name == "Omarchy AI Model Dock" and
  .version == "0.12.0" and
  (.kinds | index("bar-widget")) != null and
  .entryPoints.barWidget == "Panel.qml"
' "$plugin_dir/manifest.json" >/dev/null

bash -n "$plugin_dir/local-ai-control"
python3 -m py_compile "$plugin_dir/model-dock"
for file in "$plugin_dir/local-ai-control" "$plugin_dir/model-dock" "$plugin_dir/test.sh"; do
  [[ -x $file ]] || { printf 'Expected executable: %s\n' "$file" >&2; exit 1; }
done
"$plugin_dir/local-ai-control" --config "$plugin_dir/local-ai.example.toml" status | jq -e '
  (.profile | type == "string") and
  (.state | type == "string") and
  (.endpoint | type == "string") and
  (.configFile | type == "string") and
  (.profiles | type == "array") and
  (all(.profiles[];
    (.id | type == "string") and
    (.model | type == "string") and
    (.variant | type == "string") and
    (.context | type == "string") and
    (.unitFile | type == "string") and
    (.ready | type == "boolean")
  ))
' >/dev/null

# Exercise start with both an explicit profile and the configured default.
# A fake systemctl keeps this test self-contained and prevents it from
# starting a real model during validation.
test_root=$(mktemp -d)
server_pid=""
cleanup() {
  if [[ -n $server_pid ]]; then kill "$server_pid" >/dev/null 2>&1 || true; fi
  rm -rf -- "$test_root"
}
trap cleanup EXIT
mkdir -p "$test_root/bin"
touch "$test_root/model-Q8_0.gguf"
cat >"$test_root/config.toml" <<'EOF'
default = "Test"

[[profiles]]
name = "Test"
service = "local-ai-test.service"
EOF
cat >"$test_root/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"$LOCAL_AI_TEST_LOG"
case " $* " in
  *" show "*)
    printf '{ path=/usr/bin/llama-server ; argv[]=/usr/bin/llama-server --model %s --host 127.0.0.1 --port 8080 --device Vulkan0 --ctx-size 65536 ; ignore_errors=no ; }\n' "$LOCAL_AI_TEST_MODEL"
    ;;
  *" cat "*) exit 0 ;;
  *" is-active "*)
    [[ " $* " == *" --quiet "* ]] && exit 3
    printf 'inactive\n'
    exit 3
    ;;
  *" is-failed "*) printf 'inactive\n'; exit 1 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$test_root/bin/systemctl"
export LOCAL_AI_TEST_LOG="$test_root/systemctl.log"
export LOCAL_AI_TEST_MODEL="$test_root/model-Q8_0.gguf"
PATH="$test_root/bin:$PATH" "$plugin_dir/local-ai-control" --config "$test_root/config.toml" start Test
PATH="$test_root/bin:$PATH" "$plugin_dir/local-ai-control" --config "$test_root/config.toml" start
grep -Fxq -- '--user start -- local-ai-test.service' "$LOCAL_AI_TEST_LOG"

# Runtime labels are presentation names rather than quantization identifiers.
# Renaming one must preserve its service and update the configured default.
rename_payload='[{"id":"Test","name":"Fast everyday model"}]'
PATH="$test_root/bin:$PATH" "$plugin_dir/local-ai-control" \
  --config "$test_root/config.toml" rename-profiles "$rename_payload"
python3 - "$test_root/config.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)
assert config["default"] == "Fast everyday model"
assert config["profiles"] == [{"name": "Fast everyday model", "service": "local-ai-test.service"}]
PY
PATH="$test_root/bin:$PATH" "$plugin_dir/local-ai-control" \
  --config "$test_root/config.toml" status | jq -e '
    .defaultProfile == "Fast everyday model" and
    .profiles[0].id == "Fast everyday model" and
    .profiles[0].label == "Fast everyday model"
' >/dev/null
PATH="$test_root/bin:$PATH" "$plugin_dir/local-ai-control" \
  --config "$test_root/config.toml" start "Fast everyday model"

if "$plugin_dir/local-ai-control" --config "$test_root/missing.toml" doctor 2>/dev/null; then
  printf 'doctor unexpectedly accepted a missing config\n' >&2
  exit 1
fi

printf 'default = ""\nprofiles = []\n' >"$test_root/empty.toml"
if "$plugin_dir/local-ai-control" --config "$test_root/empty.toml" doctor >/dev/null 2>&1; then
  printf 'doctor unexpectedly accepted an empty profile list\n' >&2
  exit 1
fi

printf '[[profiles]]\nname = "Unsafe"\nservice = "../unsafe.service"\n' >"$test_root/invalid.toml"
if "$plugin_dir/local-ai-control" --config "$test_root/invalid.toml" status >/dev/null 2>&1; then
  printf 'status unexpectedly accepted an invalid service name\n' >&2
  exit 1
fi

python3 "$plugin_dir/tests/test-model-dock.py"
if command -v omarchy >/dev/null; then
  omarchy plugin validate "$plugin_dir" >/dev/null
fi
printf 'Model Dock and existing runtime compatibility checks passed\n'
