# OpenDesign 项目分析报告

> 分析日期: 2026-11-06
> 源码路径: `/home/wangwei/wei/workspacePy/design/open-design-main/`
> 版本: 0.25.1
> 许可证: Apache-2.0

---

## 一、项目定位

**OpenDesign** 自称是**首个协作式 AI 设计 Agent 工作区 (Collaborative AI Design Agent Workspace)**。核心理念是：

- **Local-first (本地优先)**：检测到本机已安装的代码 Agent CLI (Claude Code, Codex, DSH, OpenCode 等)，直接在本机运行设计技能。
- **Brief → Prototype → Review → Refine**：从一段设计简报 (brief) 出发，让 AI 编码 Agent 生成遵循设计系统的原型，团队评审后再让 Agent 在同一项目中迭代。
- **开源可扩展**：技能 (skills)、设计模板、设计系统、插件都可以检视、改编、扩展。

它同时提供桌面客户端 (Electron)、Web 客户端、OpenDesign Cloud 托管运行时 (AMR Cloud)，以及 `od` CLI 守护进程。

---

## 二、技术栈

| 层面 | 选型 |
|---|---|
| 语言 | TypeScript 7.0 (`@typescript/native`)，ESM (`"type": "module"`) |
| 运行时 | Node.js **24** (`~24`)，pnpm **10.33.2+** |
| 包管理 | pnpm workspaces (monorepo) |
| 构建工具 | esbuild, tsx (脚本即时执行) |
| 前端框架 | **Next.js 16** App Router + **React 18** (`apps/web`) |
| 桌面端 | Electron (主进程 `apps/desktop/dist/main/index.js`) |
| 数据 | better-sqlite3 (本地 SQLite)，protobufjs (协议) |
| AI/媒体 | sharp (图像处理)，onnxruntime-node (本地推理) |
| 协议/通信 | gRPC-like (sidecar-proto, launcher-proto)，MCP (Model Context Protocol) |
| 部署 | Docker, Helm chart (`charts/open-design`)，Vercel, AWS, Azure |
| **CI/CD** | GitHub Actions (**55 工作流**，双层：业务层 ci.yml + 原子能力层 atom.yml) |
| 测试 | Vitest (单元/集成) + Playwright (UI E2E + 视觉回归) |
| Mock | `mocks/`：20+ Agent CLI 的回放 mock (源自匿名 Langfuse trace) |
| Agent 集成 | Claude Code, Claude Desktop, Codex CLI, DeepSeek Reasonix, Gemini CLI, Goose, Hermes, OpenClaw, opencode, Pi |

---

## 三、Monorepo 总览

```
open-design-main/
├── apps/                 # 可部署应用
│   ├── daemon/           # `od` CLI 守护进程 (入口: od.mjs)
│   ├── web/              # Web 客户端
│   ├── desktop/          # Electron 桌面客户端
│   ├── closure/          # 可独立分发的 Closure 内容
│   └── packaged/         # 打包后的发行版本
│
├── packages/             # 共享库 (18 个)
│   ├── components/       # 设计系统组件库
│   ├── contracts/        # 类型契约
│   ├── host/             # 宿主层
│   ├── platform/         # 平台抽象
│   ├── plugin-runtime/   # 插件运行时
│   ├── launcher/         # Agent 启动器
│   ├── launcher-proto/   # 启动器协议
│   ├── sidecar/          # Sidecar 进程
│   ├── sidecar-proto/    # Sidecar 协议
│   ├── dsh-runtime/      # DeepSeek Harness 运行时
│   ├── agui-adapter/     # AG-UI 协议适配
│   ├── metatool/         # 元工具
│   ├── registry-protocol/# 注册协议
│   ├── diagnostics/      # 诊断
│   ├── download/         # 下载
│   ├── release/          # 发布
│   └── standalone/       # 独立运行
│
├── plugins/              # 插件生态
│   ├── _official/        # 官方插件
│   ├── community/        # 社区插件
│   ├── open-design/      # 核心 OD 插件
│   ├── registry/         # 插件注册表
│   └── spec/             # 插件规范
│
├── tools/                # 开发/打包/发布/服务工具链
│   ├── dev/              # 开发
│   ├── pack/             # 打包
│   ├── release/          # 发布
│   └── serve/            # 服务
│
├── shells/terminal/      # 终端 Shell 集成
├── skills/               # 170+ 设计技能 (图像/视频/PPT/动效/...)
├── design-systems/       # 160+ 设计系统主题 (Stripe/Airbnb/...)
├── design-templates/     # 120+ 设计模板 (deck/prototype/dashboard/...)
├── craft/                # 设计工艺规范文档 (色彩/排版/动效/UX 定律/...)
├── clipper/              # 浏览器扩展 (Chrome Web Clipper)
├── figma-plugin/         # Figma 插件
├── story/                # 产品故事 (STORY.md)
├── specs/                # 技术规范 (Live Artifacts, Clipper, ...)
├── templates/            # HTML 模板 (deck-framework, live-artifacts)
├── prompt-templates/     # 提示词模板 (image, video)
├── assets/               # 公共资源 (frames, prompt-templates, community-pets)
├── data/                 # 静态数据 (contributors, events, cards, plugin-previews)
├── mocks/                # 测试 mock
├── e2e/                  # Playwright E2E 测试
├── ui-audit/             # UI 审计 (goal66)
├── deploy/               # 部署配置 (Docker, AWS, Azure)
├── charts/open-design/   # Helm chart
├── scripts/              # 40+ 维护/同步/校验脚本
└── docs/                 # 文档 & i18n 翻译
```

---

## 四、核心应用 (apps/)

| 应用 | 包名 | 说明 |
|---|---|---|
| `daemon` | `@open-design/daemon` | **核心**。`od` CLI 入口，负责 Agent 调度、技能执行、制品流式预览、MCP 服务 |
| `web` | `@open-design/web` | Web 客户端，Solid.js 实现，Studio 工作区 |
| `desktop` | `@open-design/desktop` | Electron 桌面客户端，主进程 + 渲染进程 |
| `closure` | `@open-design/closure` | 可独立分发的 Closure 内容模块 |
| `packaged` | `@open-design/packaged` | 打包发行版，将 daemon+web 合并为可分发制品 |

---

## 五、核心包 (packages/)

| 包 | 角色 |
|---|---|
| `components` | 共享 UI 组件库 (`@open-design/components`) |
| `contracts` | TypeScript 类型契约，跨包协议 |
| `host` | 宿主层——封装 Node/Electron/浏览器差异 |
| `platform` | 平台抽象 (macOS/Windows/Linux 行为差异) |
| `plugin-runtime` | 插件加载、沙箱、生命周期 |
| `launcher` | Agent 启动器——发现本机 Agent CLI 并拉起 |
| `launcher-proto` | 启动器 IPC 协议 (protobuf) |
| `sidecar` | Sidecar 子进程 (长连接辅助服务) |
| `sidecar-proto` | Sidecar 协议定义 |
| `dsh-runtime` | DeepSeek Harness 原生运行时适配器 (一等公民) |
| `agui-adapter` | AG-UI (Agent UI) 协议适配器 |
| `metatool` | 元工具层 (工具的工具) |
| `registry-protocol` | 插件/技能注册表协议 |
| `diagnostics` | 运行时诊断、错误上报 |
| `download` | 制品下载管理 |
| `release` | 发布流程自动化 |
| `standalone` | 独立运行模式 (无守护进程) |

---

## 六、插件与技能体系

### 6.1 插件 (plugins/)

```
plugins/
├── spec/             # 插件规范 (manifest schema, 合约)
├── registry/         # 插件注册表数据
├── open-design/      # 核心 OD 插件 (产品内置)
├── _official/        # 官方维护的插件
└── community/        # 社区贡献插件
```

插件通过 `manifest.json` 声明能力、场景、UI 入口。`plugin-runtime` 负责加载与沙箱隔离。

### 6.2 技能 (skills/) — 170+ 个

按能力分类 (部分列举)：

| 类别 | 代表技能 |
|---|---|
| 图像生成 | `fal-generate`, `imagen`, `imagegen`, `venice-image-*`, `image-enhancer` |
| 视频 | `sora`, `fal-kling-o3`, `venice-video`, `video-hyperframes`, `video-downloader` |
| 音频/语音 | `venice-audio-speech`, `venice-audio-music`, `fal-lip-sync`, `speech` |
| 3D / WebGL | `fal-3d`, `threejs`, `webgl-experience` |
| PPT / 演示 | `pptx`, `pptx-generator`, `deck-*`, `html-ppt-*` (40+ 种风格) |
| 动效 | `gsap-*` (7 个), `remotion`, `motion-design`, `motion-lab`, `ui-animation` |
| 文档 | `pdf`, `docx`, `minimax-docx`, `minimax-pdf`, `doc`, `doc-kami-parchment` |
| 设计评审 | `design-review`, `design-consultation`, `plan-design-review` |
| 品牌 | `brandkit`, `brand-extract`, `brand-guidelines` |
| Figma 集成 | `figma-use`, `figma-create-*`, `figma-generate-*`, `figma-implement-design` |
| 前端生成 | `frontend-design`, `frontend-dev`, `frontend-skill`, `shadcn-ui` |
| 截图 / 爬取 | `screenshot`, `full-page-screenshot`, `screenshots-marketing`, `web-clone` |
| 社交内容 | `card-twitter`, `card-xiaohongshu`, `social-*` |
| 视觉风格 | `taste-skill`, `taste-skill-v1`, `brutalist-skill`, `minimalist-skill`, `soft-skill` |

### 6.3 设计系统 (design-systems/) — 160+ 个

涵盖知名品牌与设计风格：

- **品牌官方风**：`stripe`, `airbnb`, `apple`, `nike`, `tesla`, `bmw`, `ferrari`, `lamborghini`, `spacex`, `github`, `slack`, `notion`, `figma`, `vercel`, `linear-app`, `discord`, `shopify`, `uber`, `spotify`, `starbucks`, `cocacola`(未列)等
- **AI 公司风**：`openai`, `claude`, `mistral-ai`, `huggingface`, `cohere`, `nvidia`, `x-ai`, `ollama`, `perplexity`, `replicate`, `elevenlabs`, `runwayml`
- **设计风格**：`minimal`, `brutalism`, `neobrutalism`, `glassmorphism`, `neumorphism`, `claymorphism`, `skeumorphism`, `retro`, `vintage`, `futuristic`, `editorial`, `luxury`, `doodle`, `paper`, `wired` 等
- **企业/产品风**：`material`, `shadcn`, `ant`, `dashboard`, `enterprise`, `corporate`, `trading-terminal` 等
- **中文生态**：`wechat`, `xiaohongshu`, `bento`

每个设计系统是一个独立目录，包含色彩、字体、组件、令牌 (tokens) 定义。

### 6.4 设计模板 (design-templates/) — 120+ 个

按产出类型：

- **网站原型**：`web-prototype`, `web-prototype-taste-*`, `saas-landing`, `waitlist-page`, `pricing-page`
- **PPT / Deck**：`html-ppt-*` (40+ 风格), `simple-deck`, `kami-deck`, `replit-deck`
- **仪表板**：`dashboard`, `live-dashboard`, `social-media-dashboard`, `trading-analysis-dashboard-template`
- **文档 / 报告**：`blog-post`, `docs-page`, `finance-report`, `clinical-case-report`, `ib-pitch-book`, `dcf-valuation`
- **动效 / 视频**：`hyperframes`, `motion-frames`, `video-shortform`, `sprite-animation`
- **移动端**：`mobile-app`, `mobile-onboarding`
- **线框**：`wireframe-*` (5 种)
- **营销**：`email-marketing`, `social-carousel`, `image-poster`, `magazine-poster`
- **业务**：`invoice`, `meeting-notes`, `team-okrs`, `hr-onboarding`, `pm-spec`

---

## 七、辅助模块

| 模块 | 说明 |
|---|---|
| `craft/` | 设计工艺规范文档：色彩理论、排版层级、动效纪律、无障碍基线、UX 定律、RTL/BiDi、状态覆盖、反 AI 审美 slop 等 |
| `clipper/` | Chrome 浏览器扩展 (Manifest V3)，用于网页剪藏 → 设计素材 |
| `figma-plugin/` | Figma 插件 (code.js + ui.html)，桥接 Figma ↔ OpenDesign |
| `story/` | 产品故事 (`STORY.md`, `STORY.zh-CN.md`) |
| `shells/terminal/` | 终端 Shell 集成 (bash/zsh 补全等) |
| `specs/` | 技术规范：`od-clipper.md`, `live-artifacts`, `change/`, `current/` |
| `prompt-templates/` | 图像/视频提示词模板 |
| `templates/` | HTML 模板骨架 (`deck-framework.html`, `kami-deck.html`, `live-artifacts/`) |
| `ui-audit/` | UI 审计 (`goal66`) |
| `data/` | 静态数据：contributors, events, cards, plugin-previews |
| `mocks/` | 测试用 mock 代理与录制 |
| `assets/` | 公共资源：frames, prompt-templates, community-pets |

---

## 八、构建与开发工作流

### 8.1 初始化

```bash
pnpm install          # 安装所有依赖 + 运行 postinstall.mjs
pnpm bootstrap        # 等同 postinstall
```

### 8.2 开发

```bash
pnpm tools-dev        # 启动开发模式 (daemon + web + watcher)
pnpm tools-serve      # 启动纯服务模式
```

### 8.3 打包 / 发布

```bash
pnpm tools-pack       # 打包 (Electron .dmg / .exe / AppImage)
pnpm tools-release    # 发布流程
```

### 8.4 质量

```bash
pnpm typecheck        # 全仓库类型检查
pnpm lint:craft       # 校验 craft 文档引用
pnpm i18n:check       # 国际化一致性
pnpm i18n:coverage    # 翻译覆盖率报告
pnpm guard            # 发布前守卫
```

### 8.5 E2E 测试

```bash
cd e2e && pnpm exec playwright test
pnpm exec playwright test --config=playwright.visual.config.ts  # 视觉回归
```

---

## 九、部署模型

| 方式 | 说明 |
|---|---|
| **本地 CLI** | `od` (daemon) 直接在本机运行，调用本地 Agent CLI |
| **桌面客户端** | Electron 打包，包含 daemon + web，独立分发 |
| **Web (Vercel)** | `vercel.json` 配置，Next.js 静态导出到 Vercel (`apps/web/out`) |
| **Docker** | `deploy/Dockerfile` (Alpine 基础镜像)，Daemon 直接服务 API + Next.js 静态导出，无需 nginx |
| **Helm / K8s** | `charts/open-design/` Helm chart |
| **AWS / Azure** | `deploy/aws/`, `deploy/azure/` 云模板 |
| **Sealos** | 支持 Sealos 云部署 |
| **OpenDesign Cloud (AMR Cloud)** | 托管运行时，通过 `od login` 接入 |

### Docker 细节

- 镜像: `ghcr.io/nexu-io/od:latest`
- 内存限制: 384m，Node 堆: 192MB
- 认证: Basic Auth via `OD_API_TOKEN`
- 启动: `cd deploy && cp .env.example .env && docker compose up -d`
- 访问: http://127.0.0.1:7456

### 发布通道 (Release Channels)

| 通道 | 用途 | 平台身份 |
|---|---|---|
| **beta** | 日常研发/开发验证 | `Open Design Beta` |
| **prerelease** | 内部验证，稳定版前 gate | `Open Design Prerelease` |
| **preview** | 独立早期访问，稳定级严谨度 | `Open Design Preview` |
| **stable** | 正式交付通道 (需 prerelease 验证 + macOS Intel 签名) | `Open Design` |

---

## 十、Agent 集成矩阵

| Agent / 平台 | 状态 | 接入方式 |
|---|---|---|
| Claude Code | ✅ | `od mcp install claude` |
| Claude Desktop | ✅ | `od mcp install claude-desktop` |
| Codex CLI | ✅ | `od mcp install codex` |
| DeepSeek Reasonix | ✅ | `od mcp install reasonix` (DSH 为原生运行时) |
| Gemini CLI | ✅ | `od mcp install gemini` |
| Goose | ✅ | `od mcp install goose` |
| Hermes | ✅ | `od mcp install hermes` |
| OpenClaw | ✅ | `od mcp install openclaw` |
| opencode | ✅ | `od mcp install opencode` |
| Pi | ✅ | `od mcp install pi` |

接入方式分两类：
1. **Skills + CLI + MCP**：Agent 消费 OD 的能力
2. **Native runtime adapter**：OD 直接拉起 Agent (如 DSH)

---

## 十一、关键领域术语 (摘自 CONTEXT.md)

| 术语 | 含义 |
|---|---|
| **Project** | 顶层设计工作区，包含对话与设计文件 |
| **Normal Artifact** | 由 entry file + manifest 表示的设计产出 |
| **Live Artifact** | 可刷新的设计产出，存为 live-artifact 记录 |
| **Artifact Entry File** | 打开/渲染产出的主文件 |
| **Artifact Manifest** | 标识 project 文件为 artifact 的 sidecar 元数据 |
| **Active Project** | 用户最近交互的项目，MCP 工具的默认目标 |
| **Home Composer Media Surface** | Home 页创作器的媒体意图 (image/video/hyperframes/audio) |
| **Chip Rail** | Home 提示卡下方的意图 chip 行 |
| **HyperFrames** | HTML 驱动的动效生成，提交为 `kind: "video"` + `videoModel: "hyperframes-html"` |
| **AMR Cloud / AMR CLI** | 云端运行时 / 本地 CLI 运行时 |

---

## 十二、规模概览

| 维度 | 数量 |
|---|---|
| Apps | 5 |
| Packages | 18 |
| Tools | 4 (dev, pack, release, serve) |
| Plugins 目录 | 5 大类 (open-design, _official, community, registry, spec) |
| 官方插件分类 | 6 (atoms, design-systems, examples, image-templates, scenarios, video-templates) |
| Skills | **171** |
| Design Systems | **154** |
| Design Templates | **116** (其中 html-ppt 风格 40+) |
| Craft 规范文档 | 13 篇 |
| Prompt Templates | 93+ (图像 + 视频) |
| Scripts | 45+ |
| CI 工作流 | 55 (双层架构) |
| Mock Agent CLI | 20+ (claude, codex, opencode, gemini, cursor-agent, deepseek, qwen, grok, devin, hermes, kimi, kiro, ...) |
| 活跃技术规范 | 60+ (specs/current/) |
| 支持 Agent CLI | 26+ |
| i18n 语言 | 19 (ar, de, en, es-ES, fa, fr, hu, id, it, ja, ko, pl, pt-BR, ru, th, tr, uk, zh-CN, zh-TW) |

---

## 十三、架构与流程图

详见 → [ARCHITECTURE.md](./ARCHITECTURE.md) (含 Mermaid 图)

---

## 十四、总结

OpenDesign 是一个**雄心勃勃的开源 AI 设计工作区**，具备以下鲜明特征：

1. **Agent 中立**：不绑定单一模型，支持 **26+ 种编码 Agent** 通过 MCP 接入
2. **内容规模惊人**：**171 技能 × 154 设计系统 × 116 模板**，构成庞大的设计资产库
3. **Local-first 但含云端**：默认本地运行，可选 OpenDesign Cloud
4. **端到端覆盖**：Brief → 图像/视频/PPT/原型/动效/文档 → 评审 → 迭代
5. **工程化成熟**：
   - pnpm monorepo + TypeScript 7 + Node 24
   - Next.js 16 + React 18 (Web) + Electron (Desktop)
   - 严格类型契约 + protobuf 协议
   - 55 个 CI 工作流 (双层：业务层 + 原子能力层)
   - 20+ Agent CLI mock (源自匿名 Langfuse trace)
   - E2E + 视觉回归 (Playwright)
   - Helm + 多云部署 (Docker/Vercel/AWS/Azure/Sealos)
   - 四级发布通道 (beta/prerelease/preview/stable)
6. **强工艺导向**：`craft/` 目录独立维护设计工艺规范 (反 AI slop、UX 定律、排版纪律)
7. **国际化**：19 种语言完整覆盖

该项目适合用作：
- AI 辅助设计的**生产力工具**
- 设计系统的**管理与分发平台**
- 编码 Agent 接入设计领域的**标准协议实现**
- 研究 AI+设计协作的**参考架构**
- 多 Agent 编排系统的**学习样本**
