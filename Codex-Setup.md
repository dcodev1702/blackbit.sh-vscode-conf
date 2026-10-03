# Codex in VS Code

Configuration recorded on 2026-10-03 for macOS and VS Code 1.140.0.

## Installed Integration

- Official extension: **Codex - OpenAI's coding agent**, publisher **OpenAI**, identifier `openai.chatgpt`.
- Installed stable version: **26.930.31730**. VS Code reported successful signature verification and installation. Extension auto-update is enabled.
- Bundled Codex runtime: **0.160.0**. It successfully parsed the shared configuration.
- The extension manages its own runtime. No separate npm/Homebrew CLI installation or `chatgpt.cliExecutable` override is required for VS Code.
- The official extension is the preferred Codex integration. The temporary native Agent Host enablement override was removed, and `chat.editor.codex.preferAgentHost` is explicitly `false`.
- Existing Copilot and BlackBit model settings were preserved. The BlackBit provider registry is separate from Codex's provider configuration; these models are not automatically imported into Codex.

**Current status:** signed in with ChatGPT and verified inside VS Code. The Codex pane returned `CODEX_EDITOR_OK` in a local chat. Separately, the extension's bundled runtime retrieved the saved authentication, returned `CODEX_OK`, and executed a harmless shell-tool test that returned `CODEX_TOOLS_OK` with exit code 0.

## Reusable Configuration Examples

The working settings are also available as standalone, credential-free examples:

| File | Destination |
| --- | --- |
| [.vscode/codex-user-settings.example.json](.vscode/codex-user-settings.example.json) | Merge into **Preferences: Open User Settings (JSON)** for the target VS Code profile. |
| [.vscode/codex.example.toml](.vscode/codex.example.toml) | Merge into the target user's Codex configuration described below. Preserve existing plugins, MCP servers, project settings, and any unrelated root keys. |

These examples are **not loaded automatically** from this workspace. They reproduce the active model, editor, and permission settings without copying credentials or machine-specific plugin paths. The existing live setup remains user-level and does not depend on this directory.

When moving to another machine, install the official extension, merge the relevant settings, and sign in on that machine. Do not copy Keychain entries or replace the whole user configuration with these partial examples. Confirm the example's model is available to the new account before using it.

## Sign-In and First-Run Check

Sign-in is already complete on this machine. Use these steps after signing out or setting up another machine or Codex home:

1. Open the Command Palette with **Command+Shift+P**.
2. Run **Codex: Open Codex Sidebar**, or select the **Codex** tab beside Chat.
3. Sign in with your ChatGPT account if you want to use an eligible ChatGPT subscription. Complete the account selection, browser login, and any MFA yourself.
4. Use API-key sign-in only if you deliberately want separate OpenAI API billing. Enter the key through Codex's sign-in interface, not in Copilot chat or a repository file.
5. Select a model available to that account. The preserved default below must be available to the account you sign in with; otherwise choose an available model in Codex.
6. Start a new chat and send this minimal test:

   ```text
   Reply with exactly CODEX_OK. Do not read files, run tools, or make changes.
   ```

7. Confirm a response arrives, then separately test a harmless task in a disposable workspace before using Codex on sensitive evidence or production code.

If the newly installed extension does not open, finish active work and run **Developer: Reload Window**, then reopen Codex. Do not interrupt an active session just to reload the editor.

The official extension's direct ChatGPT/API sign-in is not the same as the existing Copilot sign-in. VS Code's alternative Codex Agent Host can use Copilot-backed models, but it is an experimental integration and was not selected as the final default here.

## Persistent VS Code Settings

These settings are already applied in **Preferences: Open User Settings (JSON)**. They apply across folders using this VS Code profile, unless a workspace explicitly overrides them.

```json
{
    "chat.editor.codex.preferAgentHost": false,
    "chatgpt.composerEnterBehavior": "cmdIfMultiline",
    "chatgpt.followUpQueueMode": "queue",
    "chatgpt.reviewDelivery": "inline",
    "chatgpt.openOnStartup": false
}
```

- Multiline prompts require **Command+Enter**, reducing accidental submission of pasted scripts or evidence excerpts.
- Follow-ups are queued instead of steering the current run by default.
- Reviews remain in the current Codex chat when supported.
- Codex does not take focus every time VS Code starts.
- Keep `chatgpt.cliExecutable` unset. Manually pointing the extension at an older Desktop or cached native runtime can break version-dependent features.

For another machine/profile, merge these entries into the existing User Settings object. Do not replace unrelated settings or place them in Codex's TOML configuration.

## Shared Codex Defaults

The following entries were added to the existing user-level Codex configuration:

```text
~/.codex/config.toml
```

```toml
approval_policy = "on-request"
sandbox_mode = "workspace-write"
cli_auth_credentials_store = "keyring"

[sandbox_workspace_write]
network_access = false

[shell_environment_policy]
ignore_default_excludes = false
```

These are user-level defaults shared by Codex clients using the same Codex home. They are not restricted to the BlackBit directory. Project configuration, managed policy, command-line overrides, or an explicit session permission mode can change the effective behavior.

When repeating the setup, merge the root keys before the first TOML table and merge each table's fields into any existing table. Do not append duplicate tables or replace the whole file: it can also contain existing plugins, MCP servers, and project settings.

### Why These Defaults

- **On-request approvals:** retain approval prompts when Codex requests additional permissions; this does not mean every command needs approval.
- **Workspace-write sandbox:** bound default filesystem writes to the permitted workspace and temporary locations instead of granting unrestricted access. It is not a guarantee that only workspace files can be read.
- **Restricted sandbox network:** generated shell commands do not receive unrestricted network access by default. This does not disable the model connection, and it is not a complete isolation policy for separately configured MCP servers or plugins.
- **Keychain credential storage:** keep cached sign-in credentials in macOS Keychain rather than intentionally saving plaintext credentials in a repository. Successful sign-in and subsequent authentication checks were verified with this setting enabled. Sign in again when configuring another machine or Codex home; do not export credentials into a repository.
- **Default environment exclusions:** enable Codex's automatic exclusions for common secret-bearing environment-variable names. This is not a substitute for keeping secrets out of files, explicit environment overrides, or untrusted tool inputs.

For forensic work, use copies of evidence in a dedicated workspace and select a read-only permission mode where practical. Do not assume workspace-write preserves evidence integrity. Review what data will be sent to the selected provider and comply with your organization's policies.

## Active Model and Performance Choices

The existing setup began with `gpt-5.6-terra`. During verification in VS Code, Codex selected **Daybreak Blue** and updated the shared model value. The current configuration is:

```toml
model = "gpt-daybreak-blue-latest"
model_reasoning_effort = "xhigh"
service_tier = "priority"
```

The reasoning and priority settings are previous user choices that were preserved, not a claim that they are the cheapest or fastest configuration for every task. Extra-high reasoning can increase latency and token usage; a priority tier can affect cost. For routine edits, use a lower reasoning level when the chosen model supports it. Reserve extra-high reasoning for difficult investigations or complex code analysis.

The current model was verified by the successful response inside the Codex editor. The earlier standalone runtime tests used `gpt-5.6-terra`, which also responded successfully. No API key was added and no separate OpenAI API billing route was selected; usage follows the signed-in ChatGPT account's plan. Other models and priority-tier pricing were not separately tested. Existing plugin, MCP, and project settings were preserved rather than reset or broadly enabled.

## Verification Record

- Official extension installed and signature verification succeeded.
- Every configured `chatgpt.*` setting was checked against the installed extension's configuration schema.
- Shared TOML parsed successfully with the official extension runtime 0.160.0, cached VS Code runtime 0.153.0, and existing Desktop runtime 0.133.0.
- User Settings retained the working BlackBit picker/BYOK values.
- Browser sign-in completed successfully; a separate `login status` invocation confirmed ChatGPT authentication without displaying credential values.
- The running VS Code extension reported a successful authenticated account lookup, loaded the chat history and composer, and returned exactly `CODEX_EDITOR_OK` to a no-tools prompt submitted through the editor. The completed conversation was visually verified in the Codex pane.
- An authenticated response test using `gpt-5.6-terra` returned exactly `CODEX_OK`, with no tool calls reported.
- A core shell-tool test ran `/bin/zsh -lc 'printf CODEX_TOOLS_OK'`, returned `CODEX_TOOLS_OK`, and exited with code 0.
- The two standalone runtime tests used ephemeral sessions, a read-only sandbox, and `/private/tmp` instead of the project directory. User-configured integrations were excluded from those two runs; persistent settings were not changed by the test overrides. The editor test used the actual installed extension and requested no tools, file reads, or changes.
- Custom plugins, MCP integrations, and write/network-denial behavior were not tested by these smoke checks.

## Known Diagnostics

The final log review found notices that did not prevent the verified local editor response:

- Account metadata requests to `/subscriptions` encountered a Cloudflare challenge, and `/tbo/primary` returned 404. Local authentication and chat succeeded; this does not establish that every account-management or cloud feature works. Investigate those services separately if a feature you use is affected.
- Loading history produced remote-task repository and filesystem-metadata warnings. No missing repository, placeholder file, or history entry was created or changed merely to silence these messages.
- The extension reported that `[features.guardianv2].thread_context` is deprecated and ignored. That override was not present in the inspected user, profile, or workspace configuration, so no local configuration removal was needed. The extension/runtime internals and security controls were left intact.

## References

- [Official Codex IDE setup](https://learn.chatgpt.com/docs/codex/ide)
- [Codex editor settings](https://learn.chatgpt.com/docs/developer-settings?surface=ide)
- [Shared configuration](https://learn.chatgpt.com/docs/config-file/config-basic)
- [Authentication and credential storage](https://learn.chatgpt.com/docs/auth)