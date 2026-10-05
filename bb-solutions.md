# BlackBit VOID: Persistent VS Code Model-Picker Fix

Verified configuration and troubleshooting record: 2026-10-04.

## The Fix

Use VS Code's standard model picker instead of the experimental picker. Apply this in **User settings**, not just Workspace settings:

```jsonc
{
    "chat.experimentalModelPicker": false,
    "chat.agentHost.byokModels.enabled": true
}
```

Merge these properties into the existing settings object. Do not replace the rest of your settings or add duplicate properties.

- `chat.experimentalModelPicker: false` is the workaround applied during this repair.
- `chat.agentHost.byokModels.enabled: true` was already enabled on this machine. It was preserved, not identified as the cause of the picker issue. It enables BYOK support in supported agent-host sessions.
- Open the chat model picker, expand **Other Models**, and search for a BlackBit model, such as **GLM 5.3** or **DeepSeek V4 Pro**.
- The picker can show a collapsed Other Models section again. Expand it when needed; that does not mean the provider configuration has been lost.

Both GLM 5.3 and DeepSeek V4 Pro were successfully selected through the actual VS Code picker during the original repair. DeepSeek V4 Pro was also confirmed in VS Code's saved selected-model state.

## Why This Persists

The change is stored in the VS Code **user profile**, outside this workspace and outside an individual conversation. New local chats and other workspaces using that profile inherit the user setting unless a more specific applicable setting overrides it.

Default-profile locations for stable VS Code on Windows:

| Item | Location | Purpose |
| --- | --- | --- |
| User settings | `%APPDATA%\Code\User\settings.json` | Persistent picker and BYOK settings |
| Model definitions | `%APPDATA%\Code\User\chatLanguageModels.json` | BlackBit provider, model IDs, capabilities, endpoint URLs, and secret reference |
| Local environment file | `%USERPROFILE%\.blackbit\.env` | Credential source used for direct diagnostic requests; not automatically loaded by VS Code's model provider |
| VS Code secret storage | Managed by VS Code | API-key value referenced by the model configuration |

No workspace settings file was present in this workspace when persistence was checked. All 19 BlackBit model definitions and the existing API-key reference were preserved.

### Scope and Limits

- **Availability is not the same as the default selection.** New chats may start with your configured Copilot default. Select BlackBit from the picker when you want to use it.
- A different VS Code profile, Windows account, installation, or computer may have separate settings and credentials. Repeat the setup there.
- VS Code Insiders and custom profiles can use different paths. Prefer **Preferences: Open User Settings (JSON)** and **Chat: Manage Language Models** to locate the active profile's configuration.
- Agent-host BYOK support is experimental and depends on the installed VS Code version. After enabling it on another machine, restart the agent host process. Restarting VS Code is a practical way to reinitialize local components after saving work.
- These settings do not force BlackBit into chat providers that manage their own model catalogs, such as unrelated extensions or unsupported remote/cloud session types. Use a local Copilot chat as the baseline test.
- Organization policy or service-side model maintenance can still prevent use. This repair does not bypass either.

## Apply It on Another Machine

### 1. Set the User-Level Options

1. Open VS Code using the profile in which you will create chats.
2. Open the Command Palette and run **Preferences: Open User Settings (JSON)**.
3. Add or update the two properties shown under The Fix. Leave unrelated settings intact.
4. Save the settings.
5. If the picker does not refresh, run **Developer: Reload Window**. Save other work first. If you newly enabled agent-host BYOK, restart the agent host or VS Code as well.

Use User settings so the workaround is not limited to one folder. Check Workspace settings if another workspace behaves differently.

### 2. Check the Provider

Run **Chat: Manage Language Models**. The existing provider should have:

| Property | Expected value |
| --- | --- |
| Display name | `BlackBit VOID` |
| Vendor identifier | `customendpoint` |
| API type | `chat-completions` |
| Chat endpoint | `https://void.blackbit.sh/v1/chat/completions` |
| Tools capability | Enabled for the configured models |

If BlackBit already appears there, do not delete and recreate all the model definitions just to fix picker visibility. Ensure the provider/models are not hidden by their visibility controls.

If the provider is missing, add a **Custom Endpoint** provider and configure the desired models. Two IDs verified in this repair are:

| Model | API model ID | Configured maximum input | Configured maximum output |
| --- | --- | ---: | ---: |
| GLM 5.3 | `zai_glm_5_3` | 967232 | 32768 |
| DeepSeek V4 Pro | `deepseek_v4_pro` | 1015832 | 32768 |

These are the values in the working configuration at the verification date, not a promise that the service's catalog or limits never change.

### 3. Enter the API Key on That Machine

Use the provider's API-key configuration/update action in Manage Language Models. Enter the key directly into VS Code's secret input.

> Do not assume that transferring the model JSON also transfers its credential. An `apiKey` value shaped like `${input:chat.lm.secret.<id>}` is a reference, not the API key. The destination profile must have a valid secret behind its reference. Re-enter the key through VS Code on the destination machine.

The `.env` file is not automatically consumed by this Custom Endpoint provider. Having a working `BLACKBIT_API_KEY` in that file is not proof that VS Code's saved credential is configured.

Never put the real API key or account number in this guide, chat messages, screenshots, source control, or terminal output. Do not manually edit VS Code's secret-storage database.

### 4. Verify a New Chat

1. Create a **new local Copilot chat** in the intended profile.
2. Open its model picker.
3. Expand **Other Models** and search for **GLM 5.3**.
4. Select the model. Confirm that the picker button itself changes to **GLM 5.3**.
5. Repeat with **DeepSeek V4 Pro**.
6. Send a short, nonsensitive message only if you also want to verify authentication and inference. This can incur a small provider charge.
7. Save work, restart VS Code, create another local chat, and repeat the selection check.
8. Repeat in another workspace using the same profile if cross-workspace availability is important.

Seeing a model in Manage Language Models is not the same as selecting it in a chat. Seeing an HTTP 200 response is not enough to prove successful inference either.

## Safe Configuration Check

Run this in **PowerShell 7**. It reads configuration but does not print credential values or modify files. The paths below assume the default profile in stable VS Code on Windows.

```powershell
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Run this check in PowerShell 7.'
}

$userDirectory = Join-Path $env:APPDATA 'Code\User'
$settings = Get-Content (Join-Path $userDirectory 'settings.json') -Raw |
    ConvertFrom-Json -ErrorAction Stop
$groups = Get-Content (Join-Path $userDirectory 'chatLanguageModels.json') -Raw |
    ConvertFrom-Json -ErrorAction Stop
$blackbit = @($groups | Where-Object name -eq 'BlackBit VOID')

if ($blackbit.Count -ne 1) {
    throw 'Expected one BlackBit VOID provider in this profile.'
}

[pscustomobject]@{
    StandardPickerEnabled = ($settings.'chat.experimentalModelPicker' -eq $false)
    AgentHostByokEnabled  = ($settings.'chat.agentHost.byokModels.enabled' -eq $true)
    ConfiguredModels     = @($blackbit[0].models).Count
    UsesSecretReference  = ([string]$blackbit[0].apiKey -match '^\$\{input:[^}]+\}$')
}
```

On the repaired machine, the checks returned `True`, `True`, `19`, and `True`. Another machine may legitimately have a different model count. A secret reference passing this check does not prove that its credential exists or is accepted by the service.

VS Code settings are **JSONC** and may contain comments. PowerShell 7's `ConvertFrom-Json` handles comments; Node's strict `JSON.parse` does not. Do not remove valid user comments merely because a strict JSON parser rejects the file.

## Troubleshooting Record

### Initial Investigation

1. Inspected the workspace. It initially contained only `.env`.
2. Checked environment-variable names and formatting without printing secret values.
3. Located the BlackBit provider in the user-level model configuration and confirmed there were no editor diagnostics for that configuration.
4. Searched recent Copilot and renderer logs for authentication, provider, and request failures.
5. Queried `GET https://void.blackbit.sh/v1/models` using the environment-file credential without displaying it. The catalog advertised 27 models; VS Code had 19 configured.
6. Sent tiny direct diagnostic requests to the configured models. These were not full VS Code Agent tests, and some reasoning models returned no final text with the very small output budget.
7. Investigated the provider-header warning icon and read installed VS Code/Copilot implementation code. That code was inspected only, never patched. A possible recycled warning icon did not establish whether the models could be selected or used.
8. Removed the initial temporary diagnostic outputs and in-memory credential variables.

The initial conclusion was too broad: direct API responses did not prove that the VS Code picker worked. The decisive clarification was that **none of the BlackBit models could be selected from the picker**.

### Follow-Up Checks

1. Confirmed the configuration used a saved-secret reference and that a corresponding credential record existed. Its value was not printed or changed. This did not establish that it matched the environment-file key.
2. Tested GLM 5.3 streaming directly with a fixed nonsensitive prompt. It produced `OK`, a stop finish reason, and the stream's `[DONE]` marker.
3. Tested a harmless `blackbit_ping` tool call and a follow-up tool-result message directly against GLM 5.3. The API completed that exchange. No real local tool action or workspace content was sent to BlackBit.
4. Checked model registration, capabilities, chat-session filters, and saved visibility state. The configured models advertised tool support and were registered as selectable. None of the BlackBit entries were in the saved hidden-model list.
5. Confirmed agent-host BYOK was already enabled and that the relevant chat used a local session. These were not changed as speculative fixes.
6. Disabled the experimental picker in User settings, opened the standard picker, and expanded Other Models.
7. Selected GLM 5.3 and DeepSeek V4 Pro through the actual UI. Each selection updated the picker button. Read-only inspection of saved state confirmed `customendpoint/BlackBit VOID/deepseek_v4_pro` after the original repair.
8. Rechecked settings diagnostics, preserved all 19 definitions and the secret reference, and removed temporary UI scripts and the cropped picker image.

### Automation Notes

Windows UI Automation was used to verify real selection, not just inspect JSON:

- Requested native accessibility with `AccessibleObjectFromWindow` before inspecting controls.
- Distinguished the model-picker **Button**, model-search **ComboBox**, and model-result **ListItem**. Plain text in a conversation must not be mistaken for an interactive control.
- Native mouse clicks worked after foreground activation and per-monitor DPI awareness. The picker's advertised accessibility expand action was not reliable for this test.
- Kept popup interactions together because terminal focus changes could close the menu.
- Limited output to relevant control labels; a screenshot was cropped to the chat/picker area rather than the open credential file.
- An attempted follow-up fresh-chat automation check was inconclusive: the active conversation regained focus, and session logs showed a selection in the original conversation. This is not reported as a successful fresh-chat or restart test. Use the manual checklist above for that final confirmation.

These automation details are a troubleshooting record, not prerequisites for applying the two settings or using the picker manually.

## Separate Service Findings

| Finding | Meaning and action |
| --- | --- |
| CyberKimi returned HTTP 200 with an error body containing `model_maintenance` | The service reported that CyberKimi was in maintenance and suggested CyberGLM. A local picker setting cannot repair provider maintenance. |
| HTTP 200 can contain an `error` object | Validate the response body, expected choices/text, and streaming completion, not just the status code. |
| 27 catalog entries versus 19 configured entries | Eight entries were not added during this repair. Refreshing the catalog is a separate change. |
| The catalog advertised image input for Mistral Large 3 while the existing configuration had vision disabled | Observed but left unchanged; this was not needed to fix selection. |
| Very small output budgets produced empty final content on some reasoning models | That limited probe does not establish a successful conversational response. |

## Changes and Non-Changes

| Item | Outcome |
| --- | --- |
| `chat.experimentalModelPicker` | Explicitly set to `false` in User settings |
| `chat.agentHost.byokModels.enabled` | Already `true`; preserved |
| `chat.defaultToCopilotHarness` | Observed as `false`; preserved, not a required part of this fix |
| BlackBit models | All 19 existing definitions preserved |
| API key, secret reference, and `.env` | Not changed |
| Other providers and unrelated settings | Preserved |
| VS Code/Copilot installed binaries | Not modified |
| Temporary diagnostics | Removed after use |
| This guide | Added as `bb-solutions.md` |

## Quick Diagnosis

| Symptom | Check |
| --- | --- |
| Models appear in Manage Language Models but not in the chat picker | Use the standard picker, expand Other Models, search by name, and check visibility controls. |
| Works in one workspace but not another | Check the active profile, applicable workspace/remote overrides, and chat-session type. |
| New chat starts on a Copilot model | This is a default-selection issue, not necessarily an availability failure. Open the picker and select BlackBit. |
| Works on the first machine but requests fail on the second | Re-enter the destination machine/profile's API key through VS Code. Do not rely on a copied secret reference. |
| Works in local chat but not an agent-host session | Check version support, the BYOK setting, agent-host restart, and applicable policy. |
| One model fails while other BlackBit models work | Check the response body and provider maintenance before changing shared credentials. |
| Warning triangle on the provider heading | Inspect the actual message and test selection; the icon alone is not a diagnosis. |

## Rollback

The experimental-picker setting did not have an explicit user value before this repair. To restore that previous configuration, remove only the `chat.experimentalModelPicker` entry that was added. The installed build will then use its default behavior.

Do not delete the provider, API-key reference, or existing agent-host BYOK setting as part of this rollback.

## References

- [VS Code language-model configuration](https://code.visualstudio.com/docs/agent-customization/language-models)
- [VS Code settings and scopes](https://code.visualstudio.com/docs/configure/settings)
- [VS Code profiles](https://code.visualstudio.com/docs/configure/profiles)
- [Agent-host BYOK release notes](https://code.visualstudio.com/updates/v1_128)
- [BlackBit model-catalog endpoint](https://void.blackbit.sh/v1/models) - an authenticated API endpoint, not a public health guarantee.
