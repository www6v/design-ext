# OpenDesign 架构与流程

> 配套阅读：[README.md](./README.md)
> 所有图均为 Mermaid 格式，可在支持 Mermaid 的 Markdown 渲染器 (GitHub, Notion, VSCode + 插件, Typora 等) 中直接查看。

---

## 一、整体架构图

```mermaid
graph TB
    subgraph USER["用户层"]
        U1["设计师 / 产品经理"]
        U2["工程师"]
        U3["团队评审者"]
    end

    subgraph CLIENT["客户端层"]
        WEB["Web 客户端<br/>(@open-design/web)"]
        DESKTOP["Desktop 客户端<br/>(Electron)"]
        CLI["od CLI<br/>(@open-design/daemon)"]
        FIGMA["Figma 插件"]
        CLIPPER["Chrome Clipper<br/>浏览器扩展"]
    end

    subgraph CORE["核心运行时"]
        DAEMON["Daemon 进程<br/>(任务调度 / MCP 服务)"]
        PR["Plugin Runtime<br/>(插件沙箱)"]
        LR["Launcher<br/>(Agent 发现 & 拉起)"]
        SC["Sidecar<br/>(辅助长连接服务)"]
        HOST["Host 层<br/>(平台抽象)"]
        PLAT["Platform<br/>(OS 差异封装)"]
    end

    subgraph AGENTS["编码 Agent 层"]
        CC["Claude Code"]
        CDX["Codex CLI"]
        DSH["DeepSeek<br/>Reasonix (DSH)"]
        GEM["Gemini CLI"]
        OTH["Goose / Hermes<br/>OpenClaw / opencode / Pi"]
    end

    subgraph ASSETS["设计资产库"]
        SK["Skills<br/>170+"]
        DS["Design Systems<br/>160+"]
        DT["Design Templates<br/>120+"]
        CR["Craft 规范<br/>12 篇"]
        PT["Prompt Templates"]
    end

    subgraph OUTPUT["产出 (Artifacts)"]
        IMG["图像"]
        VID["视频"]
        PPT["PPT / Deck"]
        PROTO["Web 原型"]
        MOT["动效 HyperFrames"]
        DOC["文档 PDF/DOCX"]
    end

    subgraph STORAGE["存储层"]
        SQLITE["本地 SQLite<br/>(better-sqlite3)"]
        VOL["Cua Volume<br/>(跨设备同步)"]
        FS["项目文件系统"]
    end

    subgraph CLOUD["云端 (可选)"]
        AMR["AMR Cloud<br/>(托管运行时)"]
        VERCEL["Vercel<br/>(Web 部署)"]
        K8S["K8s / Helm"]
    end

    U1 & U2 & U3 --> WEB & DESKTOP & CLI
    WEB --> DAEMON
    DESKTOP --> DAEMON
    CLI --> DAEMON
    FIGMA --> DAEMON
    CLIPPER --> DAEMON

    DAEMON --> PR
    DAEMON --> LR
    DAEMON --> SC
    DAEMON --> HOST
    HOST --> PLAT

    LR --> CC & CDX & DSH & GEM & OTH

    PR --> SK & DS & DT
    DAEMON --> CR & PT

    CC & CDX & DSH & GEM & OTH -.产出.-> OUTPUT
    OUTPUT --> FS
    FS --> SQLITE
    SQLITE --> VOL

    DAEMON <-.-> AMR
    WEB --> VERCEL
    DAEMON --> K8S

    classDef user fill:#e1f5fe,stroke:#0288d1
    classDef client fill:#fff3e0,stroke:#f57c00
    classDef core fill:#f3e5f5,stroke:#7b1fa2
    classDef agent fill:#e8f5e9,stroke:#388e3c
    classDef asset fill:#fffde7,stroke:#f9a825
    classDef output fill:#fce4ec,stroke:#c2185b
    classDef storage fill:#efebe9,stroke:#5d4037
    classDef cloud fill:#e0f2f1,stroke:#00796b

    class U1,U2,U3 user
    class WEB,DESKTOP,CLI,FIGMA,CLIPPER client
    class DAEMON,PR,LR,SC,HOST,PLAT core
    class CC,CDX,DSH,GEM,OTH agent
    class SK,DS,DT,CR,PT asset
    class IMG,VID,PPT,PROTO,MOT,DOC output
    class SQLITE,VOL,FS storage
    class AMR,VERCEL,K8S cloud
```

---

## 二、分层架构图

```mermaid
graph TB
    subgraph L1["表现层 Presentation"]
        direction LR
        P1["Web UI<br/>(Next.js 16 + React 18)"]
        P2["Desktop UI<br/>(Electron 渲染进程)"]
        P3["CLI TUI"]
        P4["Figma UI"]
    end

    subgraph L2["应用层 Application"]
        direction LR
        A1["Studio 工作区"]
        A2["Home 创作器"]
        A3["Project 管理"]
        A4["Artifact 渲染"]
    end

    subgraph L3["领域层 Domain"]
        direction LR
        D1["Project"]
        D2["Artifact<br/>(Normal / Live)"]
        D3["Skill Runner"]
        D4["Plugin Registry"]
        D5["Design System Resolver"]
    end

    subgraph L4["基础设施层 Infrastructure"]
        direction LR
        I1["Daemon 进程"]
        I2["Launcher"]
        I3["Sidecar"]
        I4["SQLite"]
        I5["Protobuf 协议"]
        I6["MCP Server"]
    end

    subgraph L5["平台层 Platform"]
        direction LR
        PL1["Node.js 24"]
        PL2["Electron 主进程"]
        PL3["Browser"]
        PL4["OS 抽象 (macOS/Win/Linux)"]
    end

    P1 & P2 & P3 & P4 --> A1 & A2 & A3 & A4
    A1 & A2 & A3 & A4 --> D1 & D2 & D3 & D4 & D5
    D1 & D2 & D3 & D4 & D5 --> I1 & I2 & I3 & I4 & I5 & I6
    I1 & I2 & I3 & I4 & I5 & I6 --> PL1 & PL2 & PL3 & PL4
```

---

## 三、核心领域模型图

```mermaid
classDiagram
    class Project {
        +id: string
        +kind: ProjectKind
        +active: boolean
        +conversations: Conversation[]
        +artifacts: Artifact[]
        +designSystem: DesignSystem
    }

    class Conversation {
        +id: string
        +messages: Message[]
        +agent: AgentRef
    }

    class Artifact {
        <<abstract>>
        +id: string
        +entryFile: Path
        +manifest: Manifest
    }

    class NormalArtifact {
        +entryFile: Path
        +manifest: ArtifactManifest
        +exports: Export[]
    }

    class LiveArtifact {
        +sourceData: SourceData
        +previewState: PreviewState
        +refreshable: boolean
    }

    class ArtifactManifest {
        +kind: ArtifactKind
        +renderer: string
        +entryFile: Path
    }

    class DesignSystem {
        +id: string
        +name: string
        +tokens: TokenSet
        +components: Component[]
        +brandAssets: BrandAsset[]
    }

    class Skill {
        +id: string
        +name: string
        +category: SkillCategory
        +scenarios: Scenario[]
    }

    class Plugin {
        +manifest: PluginManifest
        +runtime: PluginRuntime
        +capabilities: Capability[]
    }

    class Agent {
        +type: AgentType
        +cli: string
        +transport: MCP | CLI
    }

    Project "1" *-- "many" Conversation
    Project "1" *-- "many" Artifact
    Project "1" --> "1" DesignSystem
    Artifact <|-- NormalArtifact
    Artifact <|-- LiveArtifact
    NormalArtifact "1" *-- "1" ArtifactManifest
    DesignSystem "1" *-- "many" Token
    Skill "many" --> "many" Plugin
    Conversation "many" --> "1" Agent
```

---

## 四、创作流程 (Brief → Artifact)

```mermaid
sequenceDiagram
    actor User as 用户
    participant Client as 客户端<br/>(Web/Desktop)
    participant Daemon as Daemon<br/>(od)
    participant Launcher as Launcher
    participant Agent as 编码 Agent<br/>(Claude/Codex/...)
    participant PR as Plugin Runtime
    participant DS as Design System
    participant FS as 文件系统
    participant DB as SQLite

    User->>Client: 输入 Brief / 选择模板
    Client->>Daemon: POST /projects (brief + options)
    Daemon->>DB: 创建 Project 记录
    Daemon->>DS: 解析所选设计系统 tokens
    DS-->>Daemon: 返回 tokens + 组件规范

    Daemon->>PR: 加载匹配的技能 (Skill)
    PR-->>Daemon: 返回 prompt 模板 + 约束

    Daemon->>Launcher: 启动 Agent (MCP/CLI)
    Launcher->>Agent: 拉起进程, 注入上下文
    Agent-->>Launcher: MCP 握手完成

    Daemon->>Agent: 流式发送 prompt<br/>(brief + DS + skill 约束)

    loop 流式生成
        Agent->>Agent: 推理 + 代码生成
        Agent-->>Daemon: 流式 token + 工具调用
        Daemon-->>Client: SSE 推送进度
        Client-->>User: 实时显示对话 + 预览
    end

    Agent->>FS: 写入制品文件 (HTML/CSS/JSON)
    FS-->>Daemon: 文件变更事件
    Daemon->>Daemon: 生成 Artifact Manifest
    Daemon->>DB: 记录 Artifact 元数据

    Daemon-->>Client: 推送完成事件
    Client->>Client: 沙箱渲染 Live Preview
    Client-->>User: 显示最终产出

    opt 团队评审
        User->>Client: 分享项目 / 评论
        Client->>Daemon: 提交反馈
        Daemon->>Agent: 追加对话 (refine)
        Agent-->>Daemon: 迭代修改
        Daemon-->>Client: 推送新版本
    end
```

---

## 五、插件加载流程

```mermaid
flowchart TD
    Start([Daemon 启动]) --> Scan["扫描插件目录<br/>plugins/open-design/<br/>plugins/_official/<br/>plugins/community/"]
    Scan --> Parse["解析 manifest.json"]
    Parse --> Validate{"校验规范<br/>(plugins/spec/)"}
    Validate -- 不通过 --> Skip["跳过 + 诊断上报"]
    Validate -- 通过 --> CapCheck{"检查能力声明<br/>vs 当前环境"}
    CapCheck -- 缺失依赖 --> Disable["禁用 + 提示"]
    CapCheck -- 满足 --> Sandbox["进入 Plugin Runtime 沙箱"]
    Sandbox --> Register["注册到 Registry Protocol"]
    Register --> BindUI["绑定 UI 入口 (若有)"]
    BindUI --> Ready([插件就绪])
    Skip --> End([加载完成])
    Disable --> End
    Ready --> End

    style Start fill:#c8e6c9
    style Ready fill:#c8e6c9
    style End fill:#ffcdd2
    style Validate fill:#fff9c4
    style CapCheck fill:#fff9c4
```

---

## 六、Agent 接入架构

```mermaid
flowchart LR
    subgraph OD["OpenDesign"]
        D["Daemon"]
        L["Launcher"]
        MCP["MCP Server"]
        P["Protobuf IPC"]
    end

    subgraph PATH1["路径 1: OD 消费 Agent 能力"]
        CC["Claude Code"]
        CDX["Codex CLI"]
        GEM["Gemini CLI"]
        OTH["其他 Agent"]
    end

    subgraph PATH2["路径 2: OD 拉起 Agent (原生运行时)"]
        DSH["DeepSeek<br/>Reasonix"]
    end

    D --> L
    L -->|"od mcp install"| MCP
    MCP -->|"stdio / http"| CC & CDX & GEM & OTH
    L -->|"原生适配器<br/>dsh-runtime"| DSH
    DSH --> P
    P --> D

    style OD fill:#f3e5f5,stroke:#7b1fa2
    style PATH1 fill:#e8f5e9,stroke:#388e3c
    style PATH2 fill:#fff3e0,stroke:#f57c00
```

---

## 七、部署拓扑

```mermaid
graph TB
    subgraph LOCAL["本地部署 (默认)"]
        U["用户"] --> CLI["od CLI"]
        CLI --> D["Daemon<br/>(Node 24)"]
        D --> SQ["SQLite"]
        D --> AG["本地 Agent CLI"]
        D --> FS["项目文件"]
    end

    subgraph DESKTOP["桌面部署"]
        U --> E["Electron App"]
        E --> D2["内置 Daemon"]
        D2 --> SQ2["SQLite"]
        D2 --> AG2["本地 Agent"]
    end

    subgraph WEB_DEPLOY["Web 部署 (Vercel)"]
        U --> BR["浏览器"]
        BR --> V["Vercel Edge"]
        V --> BE["后端 API"]
    end

    subgraph CLOUD_DEPLOY["OpenDesign Cloud"]
        U --> GW["API Gateway"]
        GW --> AMR["AMR Runtime<br/>(托管 Agent)"]
        AMR --> VOL["Volume<br/>(跨设备同步)"]
    end

    subgraph K8S_DEPLOY["自托管 K8s"]
        U --> ING["Ingress"]
        ING --> HELM["Helm Release<br/>charts/open-design"]
        HELM --> POD["Pod<br/>(Daemon + Web)"]
        POD --> PVC["PVC (持久卷)"]
    end
```

---

## 八、数据流：Brief 到 Artifact

```mermaid
flowchart LR
    A["Brief<br/>(文本/URL/素材)"] --> B["Home Composer<br/>选择 Media Surface"]
    B --> C["Chip Rail<br/>选择场景/技能"]
    C --> D["Project 创建"]
    D --> E["Design System<br/>Resolver"]
    E --> F["Skill Loader"]
    F --> G["Prompt 合成<br/>(brief + DS + skill)"]
    G --> H["Agent Dispatch<br/>(Launcher)"]
    H --> I["流式生成"]
    I --> J["File Writer"]
    J --> K["Manifest 生成"]
    K --> L["Artifact 注册"]
    L --> M["Live Preview<br/>沙箱渲染"]
    M --> N{用户评审}
    N -- 通过 --> O["导出<br/>(PNG/PDF/MP4/HTML)"]
    N -- 迭代 --> G

    style A fill:#bbdefb
    style O fill:#c8e6c9
    style N fill:#fff9c4
```

---

## 九、技能分类与调用关系

```mermaid
flowchart TB
    subgraph INPUT["输入类型"]
        I1["文本 Brief"]
        I2["图片"]
        I3["视频"]
        I4["URL"]
        I5["Figma 文件"]
    end

    subgraph SKILL_CAT["技能类别"]
        SC1["图像生成<br/>fal-generate, imagen, ..."]
        SC2["视频生成<br/>sora, fal-kling-o3, ..."]
        SC3["音频/语音<br/>venice-audio-*, speech"]
        SC4["PPT / Deck<br/>pptx, html-ppt-*, deck-*"]
        SC5["动效<br/>gsap-*, remotion, motion-*"]
        SC6["文档<br/>pdf, docx, minimax-*"]
        SC7["前端原型<br/>frontend-*, shadcn-ui"]
        SC8["品牌/设计系统<br/>brandkit, brand-extract"]
        SC9["Figma 集成<br/>figma-*"]
    end

    subgraph MODEL["模型后端"]
        M1["fal.ai"]
        M2["Replicate"]
        M3["Venice"]
        M4["MiniMax"]
        M5["Sora"]
        M6["本地 ONNX"]
    end

    I1 & I2 & I4 --> SC1 & SC4 & SC7 & SC8
    I1 & I3 --> SC2 & SC5
    I1 --> SC3 & SC6
    I5 --> SC9

    SC1 & SC2 & SC3 & SC4 & SC5 & SC6 & SC7 --> M1 & M2 & M3 & M4 & M5 & M6
    SC8 --> DS["Design System Store"]
    SC9 --> FG["Figma API"]
```

---

## 十、发布流程

```mermaid
flowchart LR
    A["代码提交"] --> B["PR 审核"]
    B --> C["CI: typecheck + lint"]
    C --> D["CI: E2E (Playwright)"]
    D --> E["CI: 视觉回归"]
    E --> F{"守卫脚本<br/>scripts/guard.ts"}
    F -- 失败 --> G["阻断发布"]
    F -- 通过 --> H["tools-pack<br/>打包 Electron"]
    H --> I["tools-release<br/>生成 Release"]
    I --> J["GitHub Release<br/>+ tags"]
    J --> K["Vercel 部署<br/>(Web)"]
    J --> L["Helm 推送<br/>(K8s)"]
    J --> M["npm 发布<br/>(@open-design/*)"]

    style G fill:#ffcdd2
    style J fill:#c8e6c9
    style K fill:#c8e6c9
    style L fill:#c8e6c9
    style M fill:#c8e6c9
```

---

## 十一、关键设计决策

| 决策 | 选择 | 原因 |
|---|---|---|
| Monorepo 工具 | pnpm workspaces | 严格依赖隔离 + 快速链接 |
| 类型系统 | TypeScript 7 native | 更快编译，原生支持 |
| 前端框架 | Solid.js | 细粒度响应式，性能优于 React |
| 进程模型 | Daemon + Sidecar | 长连接辅助服务与主进程解耦 |
| Agent 协议 | MCP + Protobuf IPC | MCP 通用性 + Protobuf 高性能 |
| 本地存储 | SQLite | 单文件、零依赖、跨平台 |
| 插件沙箱 | Plugin Runtime | 隔离社区代码，保护宿主 |
| 设计系统分发 | 目录 + manifest | 可 git diff、可检视、可 fork |
| 部署 | Docker + Helm + Vercel | 覆盖本地/云/边缘三种场景 |
| DeepSeek 集成 | 原生运行时 (dsh-runtime) | 一等公民待遇，结构化流式 |

---

## 十二、扩展点

```mermaid
mindmap
  root((OpenDesign<br/>扩展点))
    技能 Skills
      新增 skill 目录
      接入新模型后端
      自定义工作流
    设计系统
      新增 design-systems/* 目录
      自定义 tokens
      品牌资产注入
    模板 Templates
      新增 design-templates/*
      HTML 模板骨架
      场景化 prompt
    插件 Plugins
      manifest.json 声明
      UI 入口扩展
      自定义场景
    Agent 接入
      MCP adapter
      原生 runtime
      CLI 桥接
    产出类型
      新 ArtifactKind
      新 renderer
      新 export 格式
    部署
      Docker 镜像
      Helm values
      Vercel 函数
```

---

## 十三、结论

OpenDesign 的架构体现了几个核心工程哲学：

1. **Local-first, cloud-optional**：默认本地运行保障隐私与低延迟，云端作为可选增强
2. **Agent-agnostic**：通过 MCP 抽象，不绑定任何单一 AI 提供商，支持 26+ Agent CLI
3. **Asset-rich**：171 技能 × 154 设计系统 × 116 模板，构成庞大的可组合设计资产库
4. **Process-isolated**：Daemon / Sidecar / Plugin Runtime / Agent 进程各司其职，故障隔离
5. **Protocol-driven**：protobuf 定义 IPC，MCP 定义 Agent 通信，manifest 定义插件/制品契约
6. **Design-engineering 融合**：`craft/` 目录把设计工艺 (排版/色彩/UX 定律) 提升到与代码同等地位
7. **Test-driven quality**：55 个 CI 工作流，双层架构 (业务层 + 原子能力层)，20+ Agent CLI mock，Playwright 视觉回归
8. **Release discipline**：四级发布通道 (beta → prerelease → preview → stable)，macOS Intel 签名作为 stable gate

该架构适合作为 **AI+设计协作** 领域的参考实现，也适合作为 **多 Agent 编排系统** 的学习样本。
