#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_URL="${BLACKBIT_BASE_URL:-https://void.blackbit.sh/v1}"
TIMEOUT="${BLACKBIT_TIMEOUT:-180}"
BLACKBIT_ENV_FILE="${BLACKBIT_ENV_FILE:-$SCRIPT_DIR/.env}"
BLACKBIT_KEY_LOADER="${BLACKBIT_KEY_LOADER:-$HOME/.blackbit/load-blackbit-key.sh}"
MODELS_JSON="$SCRIPT_DIR/chatLanguageModels.json"

# Used only when chatLanguageModels.json cannot be read.
FALLBACK_MODELS=(
  "adverserial_cyberkimi"
  "adverserial_cyberglm"
)

usage() {
  cat <<'EOF'
Usage:
  ./test-blackbit-models.sh [model_id ...]

With no arguments, every model in chatLanguageModels.json is tested.
These non-streaming API diagnostics can incur provider charges.
They do not verify VS Code picker selection or Agent-mode suitability.

Examples:
  ./test-blackbit-models.sh
  ./test-blackbit-models.sh zai_glm_5_3 deepseek_v4_pro
  ./test-blackbit-models.sh zai_glm_5_3

Environment:
  BLACKBIT_API_KEY     Optional. If unset, it is loaded from BLACKBIT_ENV_FILE.
  BLACKBIT_ENV_FILE    Optional (default: .env next to this script)
  BLACKBIT_KEY_LOADER  Optional alternate loader path
                       (default: ~/.blackbit/load-blackbit-key.sh, else the bundled copy).
  BLACKBIT_BASE_URL    Optional (default: https://void.blackbit.sh/v1)
  BLACKBIT_TIMEOUT     Optional seconds (default: 180)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# If the key is not already present, load it from .env through the credential loader
# (the installed copy first, then the copy bundled with this package).
if [[ -z "${BLACKBIT_API_KEY:-}" ]]; then
  if [[ ! -f "$BLACKBIT_KEY_LOADER" && -f "$SCRIPT_DIR/.blackbit/load-blackbit-key.sh" ]]; then
    BLACKBIT_KEY_LOADER="$SCRIPT_DIR/.blackbit/load-blackbit-key.sh"
  fi
  if [[ -f "$BLACKBIT_KEY_LOADER" ]]; then
    # shellcheck source=/dev/null
    source "$BLACKBIT_KEY_LOADER" </dev/null || exit 1
  else
    cat >&2 <<EOF
ERROR: BLACKBIT_API_KEY is not set and the loader was not found.

Expected loader:
  $BLACKBIT_KEY_LOADER

Add the key to:
  $BLACKBIT_ENV_FILE

and install the loader with:
  ./install-blackbit.sh
EOF
    exit 1
  fi
fi

for cmd in curl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' is required but was not found." >&2
    exit 1
  fi
done

if (( $# > 0 )); then
  MODELS=("$@")
else
  mapfile -t MODELS < <(python3 - "$MODELS_JSON" 2>/dev/null <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    for provider in json.load(f):
        if provider.get("vendor") == "customendpoint":
            for model in provider.get("models") or []:
                print(model["id"])
PY
  )
  (( ${#MODELS[@]} > 0 )) || MODELS=("${FALLBACK_MODELS[@]}")
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

auth_header="Authorization: Bearer ${BLACKBIT_API_KEY}"
json_header="Content-Type: application/json"

api_get() {
  local url="$1"
  local outfile="$2"
  curl --fail-with-body --silent --show-error \
    --max-time "$TIMEOUT" \
    -H "$auth_header" \
    "$url" \
    -o "$outfile"
}

api_post() {
  local url="$1"
  local body_file="$2"
  local outfile="$3"
  curl --fail-with-body --silent --show-error \
    --max-time "$TIMEOUT" \
    -X POST \
    -H "$auth_header" \
    -H "$json_header" \
    --data-binary "@$body_file" \
    "$url" \
    -o "$outfile"
}

printf '\nBlackBit VOID validation\n'
printf 'Endpoint: %s\n' "$BASE_URL"
printf 'Credential loader: %s\n' "$BLACKBIT_KEY_LOADER"
printf 'Models:\n'
printf '  - %s\n' "${MODELS[@]}"
printf '\n'

catalog_file="$tmpdir/catalog.json"
if ! api_get "$BASE_URL/models" "$catalog_file"; then
  echo "ERROR: Unable to retrieve $BASE_URL/models" >&2
  exit 1
fi

printf '%-42s %-8s %-12s %-12s %-15s\n' \
  "MODEL" "CATALOG" "CHAT" "TOOL_CALL" "TOOL_ROUNDTRIP"
printf '%-42s %-8s %-12s %-12s %-15s\n' \
  "------------------------------------------" "--------" "------------" "------------" "---------------"

overall_rc=0

for model in "${MODELS[@]}"; do
  model_slug="$(printf '%s' "$model" | tr -c 'A-Za-z0-9._-' '_')"

  catalog_result="$(
    python3 - "$catalog_file" "$model" <<'PY'
import json, sys

path, model_id = sys.argv[1], sys.argv[2]

try:
  with open(path, "r", encoding="utf-8") as response_file:
    obj = json.load(response_file)
  if isinstance(obj, dict) and obj.get("error") is not None:
    raise ValueError
  items = obj.get("data", []) if isinstance(obj, dict) else obj
  if not isinstance(items, list):
    raise ValueError
  match = next((item for item in items if isinstance(item, dict) and item.get("id") == model_id), None)
  model_info = (match.get("model_info") or {}) if match else {}
  if not isinstance(model_info, dict):
    raise ValueError
except (OSError, ValueError, TypeError, AttributeError):
  print("ERROR")
  raise SystemExit

if match is None:
    print("NOT_FOUND")
    raise SystemExit(0)

supports = model_info.get("supports_tools", None)

if supports is False:
    print("FOUND_FALSE")
elif supports is True:
    print("FOUND_TRUE")
else:
    print("FOUND_UNKNOWN")
PY
  )"

  if [[ "$catalog_result" != "FOUND_TRUE" && "$catalog_result" != "FOUND_FALSE" && "$catalog_result" != "FOUND_UNKNOWN" ]]; then
    printf '%-42s %-8s %-12s %-12s %-15s\n' \
      "$model" "FAIL" "SKIP" "SKIP" "SKIP"
    overall_rc=1
    continue
  fi

  chat_body="$tmpdir/${model_slug}.chat.req.json"
  chat_resp="$tmpdir/${model_slug}.chat.resp.json"

  python3 - "$model" "$chat_body" <<'PY'
import json, sys
model, out = sys.argv[1], sys.argv[2]
body = {
    "model": model,
    "messages": [{"role": "user", "content": "Reply with exactly BLACKBIT_CHAT_OK"}],
    "max_tokens": 1024,
    "temperature": 0
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(body, f)
PY

  chat_status="FAIL"
  if api_post "$BASE_URL/chat/completions" "$chat_body" "$chat_resp"; then
    chat_status="$(
      python3 - "$chat_resp" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as response_file:
        obj = json.load(response_file)
    if not isinstance(obj, dict) or obj.get("error") is not None:
        raise ValueError
    content = obj["choices"][0]["message"].get("content")
    if not isinstance(content, str) or not content.strip():
        raise ValueError
    print("PASS" if content.strip() == "BLACKBIT_CHAT_OK" else "PASS*")
except (OSError, ValueError, KeyError, IndexError, TypeError, AttributeError):
    print("FAIL")
PY
    )"
  else
    overall_rc=1
  fi

  if [[ "$chat_status" != "PASS" && "$chat_status" != "PASS*" ]]; then
    chat_status="FAIL"
    overall_rc=1
    printf '%-42s %-8s %-12s %-12s %-15s\n' \
      "$model" "PASS" "$chat_status" "SKIP" "SKIP"
    continue
  fi

  if [[ "$catalog_result" == "FOUND_FALSE" ]]; then
    printf '%-42s %-8s %-12s %-12s %-15s\n' \
      "$model" "PASS" "$chat_status" "UNSUPPORTED" "UNSUPPORTED"
    overall_rc=1
    continue
  fi

  tool_body="$tmpdir/${model_slug}.tool.req.json"
  tool_resp="$tmpdir/${model_slug}.tool.resp.json"

  python3 - "$model" "$tool_body" <<'PY'
import json, sys
model, out = sys.argv[1], sys.argv[2]
body = {
    "model": model,
    "messages": [{
        "role": "user",
        "content": "Call bb_validation_echo with value exactly BLACKBIT_TOOL_OK. Do not answer directly."
    }],
    "tools": [{
        "type": "function",
        "function": {
            "name": "bb_validation_echo",
            "description": "Harmless function used only to verify OpenAI-compatible tool calling.",
            "parameters": {
                "type": "object",
                "properties": {"value": {"type": "string"}},
                "required": ["value"],
                "additionalProperties": False
            }
        }
    }],
    # "auto" is what VS Code sends in its agent loop; a forced tool_choice gives misleading results.
    "tool_choice": "auto",
    "max_tokens": 1024,
    "temperature": 0
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(body, f)
PY

  tool_status="FAIL"
  roundtrip_status="SKIP"

  if api_post "$BASE_URL/chat/completions" "$tool_body" "$tool_resp"; then
    tool_status="$(
      python3 - "$tool_resp" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as response_file:
      obj = json.load(response_file)
    if not isinstance(obj, dict) or obj.get("error") is not None:
      raise ValueError
    msg = obj["choices"][0]["message"]
    tool_call = (msg.get("tool_calls") or [])[0]
    if tool_call["function"]["name"] != "bb_validation_echo":
      raise ValueError
    if not isinstance(tool_call.get("id"), str) or not tool_call["id"].strip():
      raise ValueError
    raw = tool_call["function"].get("arguments") or "{}"
    args = json.loads(raw) if isinstance(raw, str) else raw
    print("PASS" if args.get("value") == "BLACKBIT_TOOL_OK" else "FAIL")
except Exception:
    print("FAIL")
PY
    )"
  fi

  if [[ "$tool_status" != "PASS" ]]; then
    tool_status="FAIL"
    overall_rc=1
    printf '%-42s %-8s %-12s %-12s %-15s\n' \
      "$model" "PASS" "$chat_status" "$tool_status" "$roundtrip_status"
    continue
  fi

  round_body="$tmpdir/${model_slug}.round.req.json"
  round_resp="$tmpdir/${model_slug}.round.resp.json"

  python3 - "$model" "$tool_resp" "$round_body" <<'PY'
import json, sys
model, response_path, out = sys.argv[1], sys.argv[2], sys.argv[3]

with open(response_path, "r", encoding="utf-8") as f:
    first = json.load(f)

assistant_message = first["choices"][0]["message"]
tool_call_id = assistant_message["tool_calls"][0]["id"]

tools = [{
    "type": "function",
    "function": {
        "name": "bb_validation_echo",
        "description": "Harmless function used only to verify OpenAI-compatible tool calling.",
        "parameters": {
            "type": "object",
            "properties": {"value": {"type": "string"}},
            "required": ["value"],
            "additionalProperties": False
        }
    }
}]

body = {
    "model": model,
    "messages": [
        {
            "role": "user",
            "content": "Call bb_validation_echo with value exactly BLACKBIT_TOOL_OK. Do not answer directly."
        },
        assistant_message,
        {
            "role": "tool",
            "tool_call_id": tool_call_id,
            "content": '{"value":"BLACKBIT_TOOL_OK","status":"success"}'
        }
    ],
    "tools": tools,
    "max_tokens": 1024,
    "temperature": 0
}

with open(out, "w", encoding="utf-8") as f:
    json.dump(body, f)
PY

  roundtrip_status="FAIL"
  if api_post "$BASE_URL/chat/completions" "$round_body" "$round_resp"; then
    roundtrip_status="$(
      python3 - "$round_resp" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as response_file:
      obj = json.load(response_file)
    if not isinstance(obj, dict) or obj.get("error") is not None:
      raise ValueError
    content = obj["choices"][0]["message"].get("content")
    print("PASS" if isinstance(content, str) and content.strip() else "FAIL")
except Exception:
    print("FAIL")
PY
    )"
  fi

  if [[ "$roundtrip_status" != "PASS" ]]; then
    roundtrip_status="FAIL"
    overall_rc=1
  fi

  printf '%-42s %-8s %-12s %-12s %-15s\n' \
    "$model" "PASS" "$chat_status" "$tool_status" "$roundtrip_status"
done

cat <<'EOF'

Interpretation:

  All checks PASS
    These limited, non-streaming API checks succeeded. Verify actual VS Code
    picker selection, streaming, and Agent behavior separately.

  Chat PASS*
    The model returned nonempty text, but not the exact requested marker
    (for example a gateway persona prefix).

  Chat FAIL
    A request failed, the body contained an error or unexpected structure,
    or there was no final text. A reasoning-only response is not a pass.

  Chat PASS, Tool Call FAIL
    Check provider maintenance, output limits, and tool support before
    changing model capabilities based on one diagnostic request.

  Tool Roundtrip FAIL
    The model may emit a tool call but may not behave reliably in
    a multi-turn IDE Agent loop.

Security:
  - The API key is read from BLACKBIT_API_KEY or the .env file (keep it chmod 600).
  - This script never prints the key and never writes it anywhere.
  - The key lives only in this script's process; your shell is unchanged unless
    you sourced the loader yourself (then run: unset BLACKBIT_API_KEY).
EOF

exit "$overall_rc"
