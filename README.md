# BlackBit Models in VS Code

Repeatable setup for BlackBit models in the VS Code Copilot chat model picker.

Validated on macOS with VS Code **1.140.0**, on **2026-10-03**. All six configured models were visually confirmed in the actual picker. Model registration and visibility were verified; successful BlackBit completions, tool calls, vision, and maximum context sizes were not tested during that verification.

## Configuration Files

The exact relevant settings from the verified setup are available as separate JSON files:

| File | Purpose and destination |
| --- | --- |
| [.vscode/settings.json](.vscode/settings.json) | Active workspace settings. Contains only the pre-existing session-sync setting; BlackBit settings are inherited from User Settings and do not depend on this file. |
| [.vscode/user-settings.example.json](.vscode/user-settings.example.json) | Exact relevant user-level settings: `chat.experimentalModelPicker: false` and `chat.agentHost.byokModels.enabled: true`. Merge into **Preferences: Open User Settings (JSON)**. Unrelated personal settings are omitted. |
| [.vscode/chatLanguageModels.example.json](.vscode/chatLanguageModels.example.json) | Exact BlackBit provider fields and all six model definitions, with `apiKey` deliberately omitted. Apply through the active user-profile model configuration opened by **Chat: Manage Language Models**. |

The two `*.example.json` files are reference examples; **VS Code does not automatically load them from this directory**. Only the active workspace settings file above applies automatically here.

For a new setup, create the BlackBit provider and enter its API key using step 3 first. Then merge the model example's fields into that generated BlackBit group, preserving its existing `apiKey` reference and all other provider groups. The safest operation is to replace only that group's `models` array after confirming its name, vendor, and API type. Do not replace the entire user-profile configuration with the example or remove the generated credential reference.

## 1. Prerequisites

- VS Code with Copilot Chat enabled and the **Custom Endpoint** provider available under **Chat: Manage Language Models**.
- A BlackBit account, a valid API key, and access to the models you intend to use. BlackBit usage and billing are separate from Copilot usage.
- Permission to use third-party model providers under your organization's policies.

The endpoint used by this configuration is:

```text
https://void.blackbit.sh/v1/chat/completions
```

The API format is **Chat Completions**, not Responses or Messages.

An API key in a workspace environment file does **not** automatically configure VS Code's model provider. Enter the key through the provider's API-key prompt as described below. The existing `ACCOUNT_NUMBER` variable is not referenced by this VS Code configuration.

## 2. Make the Model Picker Predictable

The experimental picker opens on the currently selected provider. In the verified build, it showed **Copilot** while custom models were behind an icon-only sparkle tab. This made correctly registered BlackBit models look absent.

**Already applied on this machine:** both settings below are in this VS Code profile's User Settings. The models and stored API-key reference are also user-profile-wide. Opening a different folder with this profile does not require copying any workspace files. A different profile or an explicit workspace override can still change the effective settings.

For the same behavior in **all future workspaces**:

1. Open the Command Palette with **Command+Shift+P**.
2. Run **Preferences: Open User Settings (JSON)**.
3. Merge these entries into the existing settings object. Keep all unrelated settings and avoid duplicate keys.

```json
{
    "chat.experimentalModelPicker": false,
    "chat.agentHost.byokModels.enabled": true
}
```

- `chat.experimentalModelPicker: false` uses the standard, searchable picker with explicit provider labels.
- `chat.agentHost.byokModels.enabled: true` also exposes configured BYOK models to supported **Copilot agent-host sessions inside VS Code**. It is not standalone Copilot CLI configuration and does not imply support in every other agent/session type.

For an optional **workspace-only** picker override, merge this entry into **Preferences: Open Workspace Settings (JSON)** instead. This is not needed when inheriting the user-level configuration above:

```json
{
    "chat.experimentalModelPicker": false
}
```

This workspace's picker override has been removed so it inherits the User Settings, just like a new folder. Its existing session-sync setting in [.vscode/settings.json](.vscode/settings.json) is unrelated and does not need to be copied to a new workspace. Workspace settings take precedence over user settings, so check for an explicit workspace `true` if the tabbed picker returns.

## 3. Create or Reuse the BlackBit Provider

**Already configured on this VS Code profile?** Reuse the existing **BlackBit** group. Do not add a second group just because you opened another workspace. Continue to step 4 if updating its models, or step 5 if the definitions are already present.

**Fresh machine or profile:**

1. Open **Command+Shift+P** and run **Chat: Manage Language Models**.
2. Select **Add Models**, then **Custom Endpoint**. Do not choose the deprecated OpenAI-compatible provider.
3. Use **BlackBit** as the group name. If a separate display-name prompt appears, use **BlackBit** there too.
4. Enter your BlackBit API key into VS Code's provider/API-key prompt, not into Copilot chat or this document.
5. Select **Chat Completions** when asked for the API type.
6. VS Code opens the user-profile model configuration. Keep the generated provider group and its API-key reference.

For the default macOS profile, the model configuration is located at:

```text
~/Library/Application Support/Code/User/chatLanguageModels.json
```

Use **Manage Language Models** to reach the active profile's configuration rather than assuming this path when using another profile, VS Code edition, or operating system. The active model registry is a user-profile configuration. The model example under `.vscode` is only a reference and does not register models by itself.

Confirm these fields on the BlackBit provider group:

| Field | Value |
| --- | --- |
| `name` | `BlackBit` |
| `vendor` | `customendpoint` |
| `apiType` | `chat-completions` |
| `apiKey` | Keep the secret reference generated by VS Code |
| `models` | Use the array in step 4 |

The working setup stores `apiKey` as a reference beginning with `${input:` rather than a literal key. **Preserve that entire generated reference.** Do not invent a reference or copy one from another machine: the destination needs its own stored secret. Re-enter the key through VS Code's provider configuration when moving to a fresh machine/profile or rotating credentials.

Never publish the literal key, commit an environment file containing it, or include credentials in screenshots or diagnostic output.

## 4. Install the Six Model Definitions

In the existing **BlackBit** group, replace only the value of its `models` property with the array below. Keep the group's other fields, especially `apiKey`. Keep all other provider groups in the outer array.

Do **not** replace the entire model-configuration file with this array: these are model objects, not provider groups.

```json
[
    {
        "id": "zai_glm_5_3",
        "name": "BlackBit - GLM 5.3",
        "url": "https://void.blackbit.sh/v1/chat/completions",
        "apiType": "chat-completions",
        "toolCalling": true,
        "vision": false,
        "thinking": true,
        "streaming": true,
        "contextWindow": 1000000,
        "maxOutputTokens": 128000,
        "zeroDataRetentionEnabled": true,
        "supportsReasoningEffort": ["low", "medium", "high", "max"],
        "reasoningEffortFormat": "chat-completions"
    },
    {
        "id": "adverserial_cyberglm",
        "name": "BlackBit - CyberGLM",
        "url": "https://void.blackbit.sh/v1/chat/completions",
        "apiType": "chat-completions",
        "toolCalling": true,
        "vision": false,
        "thinking": true,
        "streaming": true,
        "contextWindow": 131072,
        "maxOutputTokens": 16384,
        "zeroDataRetentionEnabled": true,
        "supportsReasoningEffort": ["minimal", "low", "medium", "high", "xhigh", "max"],
        "reasoningEffortFormat": "chat-completions"
    },
    {
        "id": "adverserial_cyberkimi",
        "name": "BlackBit - CyberKimi",
        "url": "https://void.blackbit.sh/v1/chat/completions",
        "apiType": "chat-completions",
        "toolCalling": true,
        "vision": false,
        "thinking": true,
        "streaming": true,
        "contextWindow": 750000,
        "maxOutputTokens": 32768,
        "zeroDataRetentionEnabled": true
    },
    {
        "id": "deepseek_v4_pro",
        "name": "BlackBit - DeepSeek V4 Pro",
        "url": "https://void.blackbit.sh/v1/chat/completions",
        "apiType": "chat-completions",
        "toolCalling": true,
        "vision": false,
        "thinking": true,
        "streaming": true,
        "contextWindow": 1048576,
        "maxOutputTokens": 128000,
        "zeroDataRetentionEnabled": true,
        "supportsReasoningEffort": ["high", "max"],
        "reasoningEffortFormat": "chat-completions"
    },
    {
        "id": "alibaba_qwen3_8_max",
        "name": "BlackBit - Qwen 3.8 Max",
        "url": "https://void.blackbit.sh/v1/chat/completions",
        "apiType": "chat-completions",
        "toolCalling": true,
        "vision": true,
        "thinking": true,
        "streaming": true,
        "contextWindow": 1000000,
        "maxOutputTokens": 64000,
        "zeroDataRetentionEnabled": true,
        "supportsReasoningEffort": ["low", "medium", "high", "max"],
        "reasoningEffortFormat": "chat-completions"
    },
    {
        "id": "orca_orcacyber_zero_1_0",
        "name": "BlackBit - OrcaCyber Zero 1.0",
        "url": "https://void.blackbit.sh/v1/chat/completions",
        "apiType": "chat-completions",
        "toolCalling": true,
        "vision": false,
        "thinking": true,
        "streaming": true,
        "contextWindow": 1000000,
        "maxOutputTokens": 128000,
        "zeroDataRetentionEnabled": true,
        "supportsReasoningEffort": ["none", "low", "medium", "high", "xhigh", "max"],
        "reasoningEffortFormat": "chat-completions"
    }
]
```

Save the configuration and resolve any errors in VS Code's **Problems** panel before continuing.

### Important Configuration Details

- Preserve model IDs exactly, including the spelling `adverserial`. A display name can change; an API model ID cannot be guessed from that name.
- The full `/v1/chat/completions` URL and `chat-completions` API type are intentional.
- `toolCalling: true` tells VS Code to offer the model in Agent mode. It does not add tool support to the provider; validate actual tool use separately.
- Keep the `BlackBit - ` display-name prefixes so searching for BlackBit finds every model.
- In the verified build, `contextWindow` is the total input-plus-output budget. VS Code accepts it without `maxInputTokens` and derives input capacity as `contextWindow - maxOutputTokens`.
- If an older version rejects `contextWindow`, update VS Code or use `maxInputTokens` with that derived value and omit `contextWindow`. Do not enter the full context window as the input limit while also allocating output tokens.
- The limits, vision flags, and reasoning-effort options above reproduce the current local configuration; they are not independent certification of BlackBit's current service capabilities. Confirm them against your account's current model documentation when reusing this later.
- `zeroDataRetentionEnabled` is retained to match the existing configuration. It is **not** a guarantee of BlackBit's data-retention policy; check the provider's terms separately.

## 5. Verify Visibility, Then Test a Response

### Visibility Check

1. Open Copilot chat in a **Local** session first.
2. Click the current model's name in the chat input toolbar. On the verified macOS build, **Control+Command+I** focuses chat and **Command+Option+Period** opens its model picker.
3. Type **BlackBit** into the picker's search field. This is a model search, not a chat message.
4. Confirm the **BlackBit** heading and all six entries:

   - BlackBit - CyberGLM
   - BlackBit - CyberKimi
   - BlackBit - DeepSeek V4 Pro
   - BlackBit - GLM 5.3
   - BlackBit - OrcaCyber Zero 1.0
   - BlackBit - Qwen 3.8 Max

The standard picker initially emphasizes suggested/recent models; other models can be under **Other Models**. Searching BlackBit is the reliable check. Use the pin icon beside models you want to find quickly in subsequent picker openings.

If you intentionally keep the experimental picker, use the custom-provider sparkle tab beside **Copilot**, or its search control. The Copilot tab alone is not the complete list of configured providers.

### Small Response Test

Model visibility proves registration, **not** API authentication or successful inference. Test each model you plan to use:

1. Start a new, empty chat so a previous conversation is not sent to the new provider.
2. Select the desired **BlackBit - ...** model and confirm that name appears on the chat input toolbar.
3. Send this minimal prompt:

   ```text
   Reply with exactly OK. Do not call tools.
   ```

4. Confirm a response arrives without an authentication, quota, or API-format error. This is a real provider request and may be billable.
5. Separately test a harmless tool operation before relying on Agent mode. For example, in a disposable folder, ask the model to list its filenames without modifying anything, and confirm an actual successful tool result appears.

For a **Copilot agent-host session inside VS Code**, repeat the picker check in that session after enabling `chat.agentHost.byokModels.enabled`. Configuration in a local VS Code chat is not proof that an unrelated session type or standalone CLI uses the same registry.

## 6. Troubleshooting

| Symptom | Action |
| --- | --- |
| Only Copilot models appear | Set `chat.experimentalModelPicker` to `false` in the effective settings, close/reopen the dropdown, and search BlackBit. Check workspace overrides if you changed only user settings. |
| BlackBit is missing from Manage Language Models | Check the active VS Code profile. Create the Custom Endpoint group in that profile and enter its API key there. |
| Group exists, but no matching models appear | Check configuration errors, model objects inside the group's `models` array, and whether the group/models are hidden in Manage Language Models. Use its visibility controls to unhide them; do not edit VS Code's storage database. |
| Model appears outside Agent mode but not in Agent mode | Verify both the configured `toolCalling` flag and the model's real tool-calling support. |
| Local chat works, but the Copilot agent-host list differs | Confirm `chat.agentHost.byokModels.enabled` is `true` in User Settings and test a supported Copilot agent-host session. |
| Settings or model list look stale | Save both configurations, close/reopen the picker, and reopen chat. If needed, finish any active work, then run **Developer: Reload Window** and check again. |
| Authentication error, HTTP 401/403 | Re-enter the key through the provider's API-key configuration. Check account/model permissions and organization policy. Do not replace secret references with a key in this document. |
| Model not found or HTTP 404 | Confirm the full endpoint URL and exact API model ID against the current BlackBit catalog. Display labels are not API IDs. |
| Unsupported parameter or HTTP 400 | Compare the failing request option, especially reasoning effort and token limits, with that model's current BlackBit documentation. Registration does not validate these options against the service. |
| Rate limit or quota error, HTTP 429 | Check BlackBit account balance, quota, and rate limits. Changing the picker does not resolve provider billing or limits. |
| Custom Endpoint or BYOK is unavailable | Verify VS Code/Copilot availability and version, then check organization policy. Do not bypass an administrative restriction. |
| Standalone Copilot CLI does not list these models | This runbook configures VS Code and its supported agent host, not a separate terminal CLI. Follow that CLI's current provider-configuration instructions. |

For request failures, open **View: Toggle Output** and select the Copilot/Copilot Chat output channel available in your build. Review the error without sharing API keys, authorization headers, or private prompt content.

## 7. Repeat the Setup Later

**New workspace, same machine/profile:** reuse the BlackBit provider and the already-applied User Settings. No BlackBit configuration needs to be copied into the new workspace. Open the picker, search BlackBit, select a model, and perform the small response test. Check for workspace overrides if the picker differs.

**New machine or VS Code profile:** create the provider through Manage Language Models, enter the API key on that machine, install the model array, apply the settings, and repeat both verification checks. Do not assume a copied secret reference has a corresponding stored credential.

**Adding or updating a model:** obtain its exact current BlackBit API ID and capabilities, edit the existing group's `models` array, keep the BlackBit display-name prefix, and repeat visibility and response checks. Avoid duplicate IDs or duplicate provider groups.

**After a VS Code update:** check whether the experimental-picker workaround is still needed and whether the model schema has changed. Use the installed schema and current documentation rather than assuming this version-specific behavior is permanent.

Official VS Code reference: [Language Models and Custom Endpoints](https://code.visualstudio.com/docs/agent-customization/language-models).