# BlackBit VOID in VS Code

Set up BlackBit VOID in the VS Code / GitHub Copilot Chat model picker, with optional
Ubuntu command-line diagnostics. This guide follows the repair recorded on
2026-10-04 in [bb-solutions.md](bb-solutions.md).

The actual picker fix was to **disable the experimental model picker in User
settings**. Reinstalling the provider, replacing credentials, or changing model
capabilities was not required.

## 1. Apply the Picker Fix

In the VS Code profile you use for chat, run **Preferences: Open User Settings
(JSON)** from the Command Palette. Merge the properties from
[settings.example.jsonc](settings.example.jsonc) into the existing settings object:

```jsonc
{
    "chat.experimentalModelPicker": false,
    "chat.agentHost.byokModels.enabled": true
}
```

- Update existing properties rather than adding duplicates. Preserve other settings
  and JSONC comments; do not replace the whole settings file.
- Use **User** settings, not just Workspace or Remote settings. A workspace or other
  applicable override can still change the result.
- `chat.experimentalModelPicker: false` is the workaround established by the repair.
- `chat.agentHost.byokModels.enabled: true` was already enabled and was preserved.
  It enables BYOK in supported agent-host sessions; it was not identified as the cause.
- Save work and run **Developer: Reload Window** if the picker does not refresh.
  If you newly enabled agent-host BYOK, restart the agent host or VS Code as well.

The example in this repository is not loaded by VS Code automatically. Do not put
it in a workspace settings file and expect it to apply to every folder.

## 2. Check or Add the Provider

Run **Chat: Manage Language Models**. If BlackBit already exists, keep its model
definitions and saved API-key reference. Check that the provider and desired models
are not hidden; do not recreate the group just to repair picker visibility.

| Property | Expected value |
| --- | --- |
| Display name | `BlackBit VOID` |
| Vendor | `customendpoint` |
| API type | `chat-completions` |
| Model endpoint | `https://void.blackbit.sh/v1/chat/completions` |
| Tools capability | Enabled for models used in Agent mode |

### First-Time Setup on Another Machine or Profile

1. In **Chat: Manage Language Models**, add a **Custom Endpoint** provider named
   **BlackBit VOID** and choose **Chat Completions**.
2. Enter your API key directly into VS Code's secret input. Use the provider's
   **Update API Key** action when updating an existing group.
3. Open the provider's JSON configuration, or run **Chat: Open Language Models
   (JSON)**. Keep the generated `apiKey` reference and all unrelated providers.
4. Copy the desired entries from the `models` array in
   [chatLanguageModels.json](chatLanguageModels.json) into the BlackBit group's
   `models` array. Check the provider properties above and save.
5. Apply the User settings in section 1, then verify selection in section 3.

The repository template retains all 19 model definitions from the existing
configuration. It is a dated configuration snapshot, not a guarantee that every
model is currently available or that its advertised limits are unchanged.

| Model selected during the repair | API model ID | Configured max input | Configured max output |
| --- | --- | ---: | ---: |
| GLM 5.3 | `zai_glm_5_3` | 967232 | 32768 |
| DeepSeek V4 Pro | `deepseek_v4_pro` | 1015832 | 32768 |

**Credentials are separate from model definitions.** The template's
`${input:blackbitApiKey}` is only a placeholder reference, not a working credential.
Copying a `${input:chat.lm.secret.<id>}` reference from another computer does not copy
the secret behind it. Re-enter the API key through VS Code on the destination
machine/profile. Never put a literal key in the model JSON or edit VS Code's
secret-storage database.

### Configuration Location and Scope

Use the VS Code commands above to find the active profile's files. Default-profile
paths for stable VS Code are:

| File | Windows desktop | Native Linux desktop |
| --- | --- | --- |
| User settings | `%APPDATA%\Code\User\settings.json` | `~/.config/Code/User/settings.json` |
| Model definitions | `%APPDATA%\Code\User\chatLanguageModels.json` | `~/.config/Code/User/chatLanguageModels.json` |

Custom profiles, Insiders, portable installations, and a custom `XDG_CONFIG_HOME`
can use different paths. In a Windows-to-Ubuntu Remote-SSH workflow, use the active
desktop profile's configuration commands, not a guessed file under the remote
server directory. The Ubuntu helper below does not configure VS Code or its secrets.

Other workspaces using the same profile inherit its User settings unless an
applicable override takes precedence. Different profiles, accounts, installations,
and computers can have separate settings and credentials. Do not assume Settings
Sync transfers the provider configuration or its secrets.

## 3. Verify Actual Picker Selection

1. Create a **new local Copilot chat** in the intended profile. Use a **Local**
   session as the baseline if the UI offers a session-type selector.
2. Open the model picker, expand **Other Models**, and search for **GLM 5.3**.
3. Select it and confirm that the picker button itself changes to **GLM 5.3**.
4. Repeat with **DeepSeek V4 Pro**.
5. Optionally send a short, nonsensitive message to check authentication and
   inference. Provider requests can incur charges.
6. Save work, restart VS Code, create another local chat, and repeat the selection
   check. Repeat in another workspace using the same profile when needed.

The repair record establishes successful selection of both models in the actual
picker. Its follow-up fresh-chat automation was inconclusive; do the restart and
new-chat checks yourself rather than treating them as already verified.

**Other Models** may collapse again without losing the provider. New chats may
start with your Copilot default; availability does not force a default selection.
Agent-host BYOK remains experimental and version-dependent. Unsupported
remote/cloud session types, other extensions' catalogs, organization policy, and
provider maintenance are not fixed by these settings. Harness preferences such as
`chat.defaultToCopilotHarness` are not prerequisites for this repair.

## Repository Files

Commit the following files, including the hidden helper and empty environment
example. This is also the allowlist to use when preparing a shareable archive.

| File | Purpose |
| --- | --- |
| [README.md](README.md) | Setup, verification, and publication guide |
| [bb-solutions.md](bb-solutions.md) | Detailed repair evidence, limits, and safe PowerShell configuration check |
| [settings.example.jsonc](settings.example.jsonc) | Properties to merge into VS Code User settings |
| [chatLanguageModels.json](chatLanguageModels.json) | 19-model template with a placeholder secret reference |
| [.env.example](.env.example) | Empty credential template for optional shell diagnostics |
| [.gitignore](.gitignore) | Excludes local environment files and the one-off UI script |
| [install-blackbit.sh](install-blackbit.sh) | Optional Ubuntu credential-helper installer |
| [.blackbit/load-blackbit-key.sh](.blackbit/load-blackbit-key.sh) | Parses a local environment file without executing it |
| [test-blackbit-models.sh](test-blackbit-models.sh) | Optional direct API diagnostics, not a VS Code picker test |
| [test-blackbit-offline.py](test-blackbit-offline.py) | Offline regression tests with mocked responses and dummy credentials |

Do **not** publish `.env`, other populated `.env.*` files, account numbers, saved
profile state, logs, screenshots containing secrets, or VS Code secret storage.
Git ignore rules do not remove files that have already been committed, and they do
not filter an ordinary ZIP archive. If a real key was published, revoke or rotate it.

The original Windows picker-inspection script is a local, one-off UI automation
artifact. It depends on a particular window title and accessibility controls. It
is preserved locally but ignored and is not needed in the published package.

## Optional Ubuntu API Diagnostics

These tools are independent of the picker fix. They require Bash, `curl`, Python 3,
and standard Ubuntu command-line utilities. They do not install VS Code, update
User settings, or set the provider's saved credential.

### Offline Regression Checks

Run the regression suite with Python 3 on Ubuntu. It uses only the standard
library, a mock `curl`, and dummy credentials; it does not read your real key or
contact BlackBit:

```bash
python3 ./test-blackbit-offline.py -v
```

### Prepare a Local Credential

From this directory, create a private environment file only if one does not
already exist:

```bash
if [[ ! -e .env ]]; then
    install -m 600 .env.example .env
fi
chmod 600 .env
```

Edit the empty `BLACKBIT_API_KEY` value privately in your editor. Never enter the
real key into chat, command history, screenshots, or source control. Quotes,
optional `export`, CRLF line endings, and a missing final newline are accepted.
The loader parses the file; it never sources it. An account number is not required
for API requests.

The validator can use the bundled helper without installing anything:

```bash
bash ./test-blackbit-models.sh --help
bash ./test-blackbit-models.sh zai_glm_5_3 deepseek_v4_pro
```

**The second command makes billable provider requests.** With no model arguments,
the script probes every configured model, so start with a small selection. It uses
`BLACKBIT_API_KEY` when already set; otherwise it loads `BLACKBIT_ENV_FILE`
(default: `.env` next to the script) without prompting.

The checks are non-streaming Chat Completions requests: catalog membership, a
short text response, a harmless `bb_validation_echo` tool call, and a simulated
tool-result round trip. No real local tool is executed, and no workspace content
is included in those requests.

| Result | Meaning |
| --- | --- |
| `CHAT PASS` | Response text matches the requested marker |
| `CHAT PASS*` | Nonempty response text differs from the requested marker |
| `FAIL` | A request or expected response check failed; errors and empty text are not successful inference |
| `TOOL_CALL` / `TOOL_ROUNDTRIP PASS` | The direct API passed these limited tool-protocol checks |

The script exits nonzero when a check fails. HTTP 200 alone is not success: the
body can contain an `error` such as `model_maintenance`. Reasoning can also consume
the small output budget without producing final text; that probe is inconclusive,
not a successful chat response. These checks do not establish streaming support,
VS Code Agent suitability, or picker selection. The older catalog-wide results
are not a current service-health guarantee.

### Install the Helper for Interactive Use

This step is optional:

```bash
bash ./install-blackbit.sh
source ~/.blackbit/load-blackbit-key.sh
```

The installer sets the helper directory and installed script to mode `700`, and
the local `.env` to `600`. It does not read or copy the credential. The helper
defaults to `~/BlackBit-VSCode-Ubuntu/.env`; if the checkout is elsewhere, set
`BLACKBIT_ENV_FILE` to that file before sourcing it. A missing key triggers a
masked prompt only when the helper is used interactively.

Remove the credential from your current shell with `unset BLACKBIT_API_KEY`.
To rotate it, update the local environment file and separately use **Update API
Key** in each VS Code profile where you configured BlackBit. The environment file
is not automatically consumed by VS Code's Custom Endpoint provider.

## Troubleshooting and Rollback

| Symptom | Check |
| --- | --- |
| Models appear in management but cannot be selected | Standard picker, expanded Other Models, and model visibility controls |
| Works in one workspace only | Active profile, applicable setting overrides, and session type |
| New chat starts on a Copilot model | Select BlackBit; availability and default selection are separate |
| Direct API works but VS Code authentication fails | Re-enter the provider's saved API key; the shell uses a separate credential source |
| One model fails while others work | Provider maintenance and response body before changing shared credentials |
| Warning icon on the provider | Read the actual message and test selection; an icon alone is not a diagnosis |

For the full investigation and a read-only PowerShell 7 configuration check, see
[bb-solutions.md](bb-solutions.md). Do not run the Windows UI automation script as
a setup step.

To undo the picker workaround, restore the previous value of
`chat.experimentalModelPicker`. On the repaired machine it had no explicit User
value, so rollback means removing only that added property. Preserve the provider,
secret reference, and pre-existing agent-host BYOK setting.

## References

- [Repair record](bb-solutions.md)
- [VS Code language models](https://code.visualstudio.com/docs/agent-customization/language-models)
- [VS Code settings and scopes](https://code.visualstudio.com/docs/configure/settings)
- [VS Code profiles](https://code.visualstudio.com/docs/configure/profiles)
