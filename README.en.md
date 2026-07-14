# 🚀 Claude Code: Skills Collection

[![中文](https://img.shields.io/badge/lang-中文-red.svg)](README.md)
[![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

A collection of reusable [Claude Code (Anthropic CLI)](https://claude.com/claude-code) skills. Each skill lives in its own directory — install what you need.

## 📦 Included Skills

| Skill | One-liner | When to use |
|---|---|---|
| [`crystallize`](crystallize/) | After solving a problem, deeply review the path / failed attempts / blast radius and append to `docs/THOUGHTS.md` | Auto or manual `/crystallize` after conquering a hard bug |
| [`multi-agent-scaffold`](multi-agent-scaffold/) | One-click scaffold for a multi-agent dev workflow (1 master + 5 sub-agents) | Want an agent team, parallel testing, resume-after-crash, unattended long runs |

The two complement each other: **scaffold** produces the collaborative dev pipeline, **crystallize** distills the pitfalls along the way — `multi-agent-scaffold`'s `/crystallize-experience` reuses `crystallize`'s `docs/THOUGHTS.md` format.

## 🚀 Quick Install

### Method A: One-Click Install (Recommended)

```bash
git clone https://github.com/YAHU2024/claude-skills.git
cd claude-skills
chmod +x install.sh
./install.sh
```

### Method B: Manual Install

Copy the skill directories you want into your Claude Code skills directory:

```bash
# Global (recommended, available in every project)
cp -r crystallize           ~/.claude/skills/
cp -r multi-agent-scaffold  ~/.claude/skills/

# Or per-project only
cp -r crystallize           <your-project>/.claude/skills/
cp -r multi-agent-scaffold  <your-project>/.claude/skills/
```

## 📄 License

[MIT License](LICENSE)
