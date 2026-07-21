# Install

**Any chat window already open before you install will not get the new agents or hooks, full stop — not after `/reload-plugins`, not ever, until you close it and start a new one.** Claude Code loads agent definitions and hook registrations once when a session starts; there's no live reload for those two things. New chats opened after install work immediately. See [FAQ.md](FAQ.md) for more on this.

## As a plugin (recommended)

```
/plugin marketplace add reganomika/Bullpen
/plugin install bullpen@bullpen
```

A local clone path works the same way in place of `reganomika/Bullpen`. Registers all four agents, all four skills, and both hooks in one step. Restart Claude Code (or `/reload-plugins`) once after install; skill edits apply live from then on.

`CLAUDE.md.example` never auto-installs — the plugin system doesn't load CLAUDE.md files. Append it to your own `~/.claude/CLAUDE.md` by hand.

## Copy into your own config (no plugin system)

```bash
git clone <this-repo-url>
cp <repo>/agents/*.md ~/.claude/agents/
cp -r <repo>/skills/model-routing <repo>/skills/usage-report <repo>/skills/refresh-rules <repo>/skills/routing-status ~/.claude/skills/
mkdir -p ~/.claude/hooks
cp <repo>/hooks/route-gate.sh <repo>/hooks/context-check.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/route-gate.sh ~/.claude/hooks/context-check.sh
```

Add to `~/.claude/settings.json` (merge into your existing file):

```json
{
  "hooks": {
    "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/context-check.sh" }] }],
    "PreToolUse": [{ "matcher": "Agent|Task", "hooks": [{ "type": "command", "command": "~/.claude/hooks/route-gate.sh" }] }]
  }
}
```

Start a new session to pick up the agents, skills, and hooks — chats already open when you do this stay on old behavior until restarted, no exceptions. Append `CLAUDE.md.example` to your own CLAUDE.md if you want it. Off switch for either hook: `touch ~/.claude/hooks/<name>.disabled`, back on with `rm`.

## Try without installing

```bash
claude --plugin-dir <path-to-this-repo>
```
