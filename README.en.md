# 🚀 Claude Code: Advanced Crystallize Skill

[![中文](https://img.shields.io/badge/lang-中文-red.svg)](README.md)
[![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

A global advanced agent skill designed for **Claude Code (Anthropic CLI)**.

After you conquer a hard bug, complete a refactor, or reset an environment config, this skill helps you **deeply review the problem-solving path, document failed attempts, and map affected modules** — then appends everything to your project's `docs/THOUGHTS.md` in a clean `<details>` format.

---

## ✨ Core Features

- **Append-Only Timeline**: Moves forward like a dev diary — never destroys or overwrites historical assets.
- **Deep "Rejected Solutions" Logging**: Records not only what worked but also the dead ends you hit, so humans can review them later and AI won't fall into the same logic loop again.
- **VS Code Deep Integration**: Automatically opens the doc in VS Code via `code -r` after writing.
- **Future-Ready RAG Retrieval**: Built-in high-frequency engineering category tags, keyword tags, and reuse value ratings — ideal for VS Code global search or vector knowledge base ingestion.

## 📦 Quick Install

### Method A: One-Click Global Install (Recommended)
Clone the repo and run the install script:

```bash
git clone https://github.com/Yahu2025/claude-skill-crystallize.git
cd claude-skill-crystallize
chmod +x install.sh
./install.sh
```

### Method B: Manual Global Install

Copy the `crystallize/SKILL.md` file from this repo to your global skills directory:

`~/.claude/skills/crystallize/SKILL.md`

## 🚀 Usage

Launch your `claude` terminal:

1. **Manual Precise Trigger**:

   After tackling a complex problem, type this in Claude Code:

   ```bash
   /crystallize
   ```

2. **Natural Language Trigger**:

   Tell Claude: "Help me review and document the Docker troubleshooting process I just went through."

## 📄 License

[MIT License](LICENSE)
