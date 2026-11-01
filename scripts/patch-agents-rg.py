#!/usr/bin/env python3
"""把「禁止 grep 递归、一律用 rg」写进全机所有 agent 规则文件。"""
from pathlib import Path

HOME = Path(r"C:\Users\Administrator")

FULL = """
## 检索工具（强制，2026-11-02）

- **搜文件内容一律用 `rg`（ripgrep），禁止 `grep` / `grep -r` 递归扫目录。**
  WSL 内已装好 `/home/ubuntu/bin/rg`（14.1.0，无 root 解包安装并软链到 `~/bin/rg`）；
  Windows 侧用内置搜索或 `rg.exe`。
- 按文件名找文件用 `rg --files`、`rg --files -g "*.inf"` 或 Glob 工具，
  **不要 `find /` 或 `find . -name` 全盘扫**。
- 多模式用 `rg -e A -e B`，要上下文用 `-A/-B/-C`，按类型过滤用 `-g '*.c'`。
- 只有 `rg` 确实不可用时才退回 `grep`，且必须在回复里说明原因。
- 本机历史上多次因为 `grep -r` 扫大目录拖慢任务，此规则对所有 agent 生效，不设例外。

"""

SHORT = """
## 检索工具（强制，2026-11-02）

搜文件内容一律用 `rg`（ripgrep），**禁止 `grep` / `grep -r` 递归扫目录**；按文件名找用
`rg --files` 或 Glob，不要全盘 `find`。`rg` 不可用时才退回 grep，且要说明原因。
完整说明见 `C:\\Users\\Administrator\\.codex\\AGENTS.md`。
"""

CHANGE = "- 2026-11-02：新增「检索工具」强制规则：搜内容一律用 `rg`，禁止 `grep` 递归扫目录。"

TARGETS_FULL = [HOME / ".codex" / "AGENTS.md"]
TARGETS_SHORT = [
    HOME / ".workbuddy" / "AGENTS.md",
    HOME / ".zcode" / "AGENTS.md",
    HOME / ".qoder" / "AGENTS.md",
    HOME / ".dsh" / "AGENTS.md",
    HOME / ".config" / "opencode" / "AGENTS.md",
    HOME / ".claude" / "CLAUDE.md",
    HOME / ".gemini" / "GEMINI.md",
    HOME / ".copilot" / "copilot-instructions.md",
]


def patch(path: Path, block: str, with_change: bool) -> str:
    if not path.exists():
        return "missing"
    text = path.read_text(encoding="utf-8")
    if "检索工具（强制" in text:
        return "already"

    if with_change and "## 变更记录" in text:
        idx = text.index("## 变更记录")
        new = text[:idx] + block.lstrip("\n") + "\n" + text[idx:]
        # 追加变更记录
        new = new.rstrip("\n") + "\n" + CHANGE + "\n"
    else:
        new = text.rstrip("\n") + "\n" + block

    path.write_text(new, encoding="utf-8")
    return "patched"


for p in TARGETS_FULL:
    print(f"{patch(p, FULL, True):8s} {p}")
for p in TARGETS_SHORT:
    print(f"{patch(p, SHORT, False):8s} {p}")
