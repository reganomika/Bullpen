# Install

**The hook needs a restart, no exceptions.** Claude Code registers `PreToolUse`/`Stop` hooks from `settings.json` once when a session starts. A chat already open when you install won't run `route-gate.sh` until you close it and start a new one, `/reload-plugins` doesn't help either.

**Agents are more forgiving on the copy-into-config path, less certain on the plugin path.** Claude Code watches `~/.claude/agents/` and `.claude/agents/` directly and picks up new or edited files there within seconds, no restart, as long as that directory already existed when the session started (a brand-new `~/.claude/agents/` still needs a restart to be noticed at all the first time). Plugin-delivered agents load through a different mechanism; we haven't verified whether they get the same live pickup, so treat the plugin path as needing a restart too until proven otherwise. New chats opened after install always work immediately, either way. See [FAQ.md](FAQ.md) for more on this.

## As a plugin (recommended)

```
/plugin marketplace add reganomika/Bullpen
/plugin install bullpen@bullpen
```

A local clone path works the same way in place of `reganomika/Bullpen`. Registers all four agents, all four skills, and the hook in one step. Restart Claude Code (or `/reload-plugins`) once after install; skill edits apply live from then on.

`CLAUDE.md.example` never auto-installs: the plugin system doesn't load CLAUDE.md files. Append it to your own `~/.claude/CLAUDE.md` by hand.

## Copy into your own config (no plugin system)

```bash
git clone <this-repo-url>
cp <repo>/agents/*.md ~/.claude/agents/
cp -r <repo>/skills/model-routing <repo>/skills/usage-report <repo>/skills/refresh-rules <repo>/skills/routing-status ~/.claude/skills/
mkdir -p ~/.claude/hooks
cp <repo>/hooks/route-gate.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/route-gate.sh
```

Add to `~/.claude/settings.json` (merge into your existing file):

```json
{
  "hooks": {
    "PreToolUse": [{ "matcher": "Agent|Task", "hooks": [{ "type": "command", "command": "~/.claude/hooks/route-gate.sh" }] }]
  }
}
```

Start a new session to pick up the hook, always, no exceptions. If `~/.claude/agents/` already had files in it before you ran this, Claude Code should notice the four new agent files within seconds in an already-open chat, per its own docs on watching that directory; if the directory didn't exist before, or if it doesn't show up, restart to be sure. Append `CLAUDE.md.example` to your own CLAUDE.md if you want it.

## Disable temporarily

`touch ~/.claude/hooks/route-gate.disabled`, checked fresh on every run, no restart needed. Back on: `rm ~/.claude/hooks/route-gate.disabled`.

## Uninstall

**Plugin install:**

```
/plugin uninstall bullpen@bullpen
```

Removes all four agents, all four skills, and the hook registration. If you also want the marketplace source gone: `/plugin marketplace remove reganomika/Bullpen`.

**Copy-into-config install:** nothing tracks what the manual method copied, so remove it by hand:

```bash
rm ~/.claude/agents/{cheap,dev,hard,super}.md
rm -rf ~/.claude/skills/{model-routing,usage-report,refresh-rules,routing-status}
rm ~/.claude/hooks/route-gate.sh
```

Then remove the `route-gate.sh` entry from the `PreToolUse` array in `~/.claude/settings.json` yourself, and delete the "Agent routing (kernel)" and "Tokens and models" sections from your `~/.claude/CLAUDE.md` if you appended `CLAUDE.md.example`. Either way, this only takes effect for chats started after you do it, same restart rule as install.

## Try without installing

```bash
claude --plugin-dir <path-to-this-repo>
```
