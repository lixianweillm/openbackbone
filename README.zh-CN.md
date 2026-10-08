# openbackbone

[English](./README.md) | 简体中文

可维护项目的主干:规格、决策、术语、架构和路线图随代码一起保持为真。

OpenSpec 让项目的规格保持真实。openbackbone 把同样的纪律扩展到项目持续维护(人和 agent)所需的其他文档:路线图、术语表、架构概览、决策记录和 README。

| 文档 | 回答的问题 |
|---|---|
| `ROADMAP.md` | 接下来做什么? |
| `GLOSSARY.md` | 东西叫什么? |
| `openspec/specs/` | 系统做什么? |
| `docs/architecture.md` | 系统现在长什么样? |
| `docs/adr/` | 为什么是这样? |
| `README.md` | 新人怎么上手? |

## 安装

需要 Git、Bash 和 OpenSpec CLI。在你的 Git 项目根目录运行:

```bash
npm install -g @fission-ai/openspec@latest
curl -fsSL https://raw.githubusercontent.com/lixianweillm/openbackbone/main/init.sh | bash
```

或使用本地源码:

```bash
git clone https://github.com/lixianweillm/openbackbone.git
cd /path/to/your-project
/path/to/openbackbone/init.sh
```

| 参数 | 默认值 | 含义 |
|---|---|---|
| `--with` | `openspec,docs,skills,hooks` | 要安装的组件 |
| `--tools` | `agents,claude` | agent 目标:`agents` 写入 `AGENTS.md` 和 `.agents/skills/`;`claude` 额外写入 `CLAUDE.md` 和 `.claude/skills/`。其他 OpenSpec 工具 id 会传给 `openspec init` |
| `--language` | `English` | 新建 OpenSpec 产物的语言(仅对新项目生效) |

重复运行即升级。安装器只重写它托管的内容:`AGENTS.md` 和 `CLAUDE.md` 中的标记区块、schema、skill、`docs/adr/README.md` 和 `scripts/pre-commit.sh`。你的路线图、术语表、架构概览、ADR 和 README 不会被覆盖。`.openbackbone.yaml` 记录安装的内容和来源版本;只有升级带来变化时它才会变,可以提交进版本库。

缺少 OpenSpec CLI,或 `core.hooksPath` 指向仓库之外时,对应组件会被跳过,安装器会给出修复方法。如果 `CLAUDE.md` 是符号链接或已经引入了 `AGENTS.md`,安装器不会改动它。

## 使用

向 coding agent 描述需求即可。小修复直接改。重要变更经过五个产物:

```text
proposal → specs → design → impact → tasks → 实现 → 归档
```

- **proposal** 指明它交付的路线图条目。
- **specs** 只使用术语表中的术语。
- **design** 以架构概览和现行 ADR 为起点。
- **impact** 声明本次变更对 ADR、术语表、架构、路线图和 README 的影响,每项填 `Updated`、`Planned` 或 `Not affected: <理由>`。
- **tasks** 以 "Living documents" 分组结尾:每条 `Planned` 对应一个任务。

探索性工作使用 `openspec new change <name> --schema minimalist`。

### 决策记录保持精简

只有当一个决策难以逆转、脱离上下文会让人意外、并且来自真实权衡时,才写 ADR。它由一个陈述选择的标题和一段说明理由的文字组成。已接受的 ADR 不可修改,只能由新的 ADR 取代。见 [docs/adr/README.md](./docs/adr/README.md)。

### pre-commit 钩子

以下提交会被拒绝:

- 修改、重命名或删除已有 ADR;
- 新增的 ADR 含有 Requirement 或 Scenario 小节;
- 暂存的 `impact.md` 有空小节;
- 含有无效的规格,或已有 delta spec 的变更无效(只有 proposal 的变更可以提交);
- 归档的变更仍有未完成的任务。

维护时可用 `OPENBACKBONE_SKIP_HOOKS=1` 跳过。

## 仓库结构

```text
init.sh                 安装器
AGENTS.md               安装到目标项目的规则
openspec/schemas/       spec-driven-with-impact(默认)、minimalist
skills/                 domain-modeling、openspec-git-discipline、tech-doc
templates/              路线图、术语表、架构概览的起始模板
scripts/                pre-commit 检查、回归测试
docs/                   openbackbone 自身的架构概览和 ADR
```

见 [docs/architecture.md](./docs/architecture.md) 和 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 致谢与许可证

[MIT](./LICENSE)。基于 [OpenSpec](https://github.com/Fission-AI/OpenSpec) 构建。`domain-modeling` skill 借鉴了 [Matt Pocock 的同名 skill](https://www.aihero.dev/skills-domain-modeling)。
