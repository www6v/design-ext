# OpenDesign Agent 媒体生成流程分析

> Agent (Claude Code) 如何使用「媒体生成提供商」中配置的模型

---

## 核心结论

你的理解大体正确，但有一个关键的中间环节：**Settings 页面配置的提供商 ≠ Agent 直接使用的模型**。Agent 选择哪个模型生图，由三层配置共同决定，而不是仅由 Settings 页面的「媒体生成提供商」决定。

---

## 1. 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│  Settings 页面 (http://127.0.0.1:7456/settings)              │
│  - 选择提供商: Custom Image API                              │
│  - 填写 Base URL / API Key / Model                          │
│  - 保存到 .od/media-config.json                             │
└──────────────────────────┬──────────────────────────────────┘
                           │ 写入凭证
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  .od/media-config.json (媒体提供商凭证)                       │
│  {                                                          │
│    "providers": {                                           │
│      "custom-image": {                                      │
│        "baseUrl": "http://100.94.242.79:7865/v1",           │
│        "apiKey": "",                                        │
│        "model": "sdxl"                                      │
│      }                                                      │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  项目 metadata (SQLite 数据库)                                │
│  - kind: "image"                                            │
│  - imageModel: "custom-image"  ← 这个字段决定 Agent 用哪个   │
└─────────────────────────────────────────────────────────────┘
```

**两层是独立的**：
- `media-config.json`：注册了哪些提供商可用（凭证层）
- 项目 `imageModel`：告诉 Agent 用哪个提供商（决策层）

---

## 2. Agent 选择模型的决策链

当 Agent (Claude Code) 需要生成图片时，它通过 system prompt 中的指令来决定使用哪个模型。决策优先级如下：

```
1. 用户消息中明确指定的模型（最高优先级）
   ↓ 没有
2. Web UI 每次对话发送的 byokMediaDefaults.imageModel
   ↓ 没有
3. 项目 metadata.imageModel（仅当 kind="image" 时写入 prompt）
   ↓ 没有
4. 默认值: vela/gpt-image-2（兜底）
```

**关键代码位置**：
- 兜底逻辑：`apps/daemon/src/prompts/system.ts:575`
  ```typescript
  imageModel: defaults?.imageModel?.trim() || 'vela/gpt-image-2'
  ```
- 模型选择指令：`apps/daemon/src/prompts/media-contract.ts:508-510`
  ```
  Image, default / no preference stated: use an explicitly named model
  in the current user message, then the run-scoped BYOK image default,
  then the project metadata's imageModel if set; otherwise use vela/gpt-image-2
  ```

---

## 3. 三条数据通路详解

### 通路 A：Settings 页面 → media-config.json（凭证注册）

用户在 Settings 页面配置 Custom Image API：

| 设置项 | 值 |
|--------|-----|
| API Key | (空，GPU 无需认证) |
| Base URL | `http://100.94.242.79:7865/v1` |
| Model | `sdxl` |

这会写入 `.od/media-config.json`。这一步只是**注册了 `custom-image` 这个提供商可用**，并告诉 daemon 如何连接它。

**但这不会自动让 Agent 使用 `custom-image`。**

### 通路 B：项目 metadata.imageModel（Agent 的模型选择指令）

项目的 `metadata.imageModel` 字段告诉 Agent 应该用哪个模型。

**只有当项目 `kind = "image"` 时**，这个字段才会被写入 Agent 的 system prompt：

```typescript
// system.ts:1878-1880
if (metadata.kind === 'image') {
  lines.push(`- **imageModel**: ${metadata.imageModel ?? '(not provided)'}`);
}
```

如果 `imageModel` 为空，Agent 看到的是 `imageModel: (not provided)`，然后走兜底逻辑选 `vela/gpt-image-2`。

### 通路 C：Web UI byokMediaDefaults（每次对话请求携带）

Web UI 在每次发起对话时，通过 `byokMediaDefaultsForRun()` 函数构建模型默认值：

```typescript
// ProjectView.tsx:1997-2001
const imageModel = firstNonBlank(
  input.imageModelOverride,      // UI 上的模型覆盖选择
  input.config.byokImageModel,   // 全局 app config 设置
  input.imageModelOptions[0]?.id // 项目可用的第一个模型
);
```

这个值通过 HTTP 请求体传给 daemon，最终注入 Agent 的 system prompt。

---

## 4. Agent 实际执行生图的过程

Agent 收到 system prompt 后，执行生图的命令是：

```bash
"$OD_NODE_BIN" "$OD_BIN" media generate \
  --surface image \
  --model <模型名> \
  --prompt "..." \
  --output "output.png"
```

daemon 收到 `od media generate --model custom-image` 后：
1. 读取 `media-config.json`，找到 `custom-image` 提供商的凭证
2. 用 `baseUrl` + `apiKey` 调用 OpenAI 兼容的 `/v1/images/generations` 接口
3. GPU 机器上的 diffusers 服务处理请求，返回图片

---

## 5. 当前问题的根因

查看数据库中的项目：

| 项目名 | kind | imageModel | 结果 |
|--------|------|------------|------|
| VR Headset Exploded View Poster | image | **NULL** | ❌ Agent 走兜底 → vela/gpt-image-2 → 失败 |
| Cyberpunk Anime Portrait | (空) | custom-image | 非 image kind，prompt 不显示 imageModel |
| Vintage Sign-Painter Sketch | image | vela/gpt-image-2 | 明确选了 vela |

**VR Headset 项目失败的原因**：
- `kind = "image"` ✓ → system prompt 会包含 imageModel 行
- `imageModel = NULL` → prompt 显示 `(not provided)` → 走兜底 → `vela/gpt-image-2`
- `vela/gpt-image-2` 需要 vela binary → 本地没有 → 报错

---

## 6. 正确的配置方式

要让 GPU 生图工作，需要确保**两个条件同时满足**：

### 条件 1：Settings 页面配置 Custom Image API ✓

已配置：
- Base URL: `http://100.94.242.79:7865/v1`
- Model: `sdxl`

### 条件 2：项目的 imageModel 必须设为 custom-image

通过 API 设置：
```bash
curl -X PATCH http://127.0.0.1:7456/api/projects/<PROJECT_ID> \
  -H "Content-Type: application/json" \
  -d '{"metadata": {"imageModel": "custom-image"}}'
```

**注意**：只有项目 `kind = "image"` 时这个设置才生效。对于非 image 类型的项目，需要在 Web UI 的对话界面手动选择模型覆盖（`imageModelOverride`）。

---

## 7. 流程总结图

```
用户点击"生成图片"
       │
       ▼
┌──────────────────────────────────────────┐
│  Web UI 发起对话请求                       │
│  body: {                                 │
│    byokMediaDefaults: {                  │
│      imageModel: "custom-image"  ←(C)    │
│    }                                     │
│  }                                       │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Daemon 构建 System Prompt               │
│                                          │
│  1. 项目 metadata (kind=image):          │
│     imageModel: custom-image  ←(B)       │
│                                          │
│  2. byokMediaDefaults:                   │
│     imageModel: custom-image  ←(C)       │
│                                          │
│  3. media-contract 指令:                 │
│     "use custom-image for image gen"     │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Agent (Claude Code) 执行命令:            │
│  od media generate --model custom-image  │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Daemon 查找 media-config.json:          │
│  providers.custom-image.baseUrl          │
│  → http://100.94.242.79:7865/v1  ←(A)   │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  GPU diffusers 服务生图                   │
│  POST /v1/images/generations             │
│  model: sdxl                             │
└──────────────────────────────────────────┘
```

---

## 8. 常见误解

| 误解 | 实际 |
|------|------|
| Settings 配了 Custom Image API，Agent 就会自动用它 | ❌ Settings 只注册提供商，不决定 Agent 选哪个 |
| media-config.json 里的 model 字段会告诉 Agent 用什么模型 | ❌ 那个 model 是提供商的默认模型，不是 Agent 选择指令 |
| 所有项目类型都受 imageModel 影响 | ❌ 只有 kind="image" 的项目才在 prompt 中显示 imageModel |
| CLI 能生图但 Web UI 不行 | CLI 直接指定 `--model custom-image`，绕过了 Agent 决策层 |

---

## 9. 通用解决方案

### 问题本质

Settings 页面配置的 Custom Image API 只注册了提供商凭证（`media-config.json`），但 **不影响 Agent 的模型选择逻辑**。Agent 选择模型的兜底值是硬编码的 `vela/gpt-image-2`，而本地没有 vela binary，导致所有项目生图失败。

### 已实施的方案（配置层）

**批量更新所有 image 类项目的 `imageModel`**：

```bash
# 备份
cp .od/app.sqlite .od/app.sqlite.bak

# 将所有 kind=image 的项目的 imageModel 设为 custom-image
sqlite3 .od/app.sqlite "
UPDATE projects
SET metadata_json = json_set(metadata_json, '$.imageModel', 'custom-image'),
    updated_at = (strftime('%s','now') * 1000)
WHERE json_extract(metadata_json, '$.kind') = 'image';
"
```

这确保 Agent 在 system prompt 中看到 `imageModel: custom-image`，而不是 `(not provided)` → 兜底 → `vela/gpt-image-2`。

### 方案原理图

```
修改前:
  system prompt → "imageModel: (not provided)"
  → media-contract: "otherwise use vela/gpt-image-2"
  → Agent 执行: od media generate --model vela/gpt-image-2
  → 失败: "vela binary not found"

修改后:
  system prompt → "imageModel: custom-image"
  → media-contract: "use project metadata's imageModel"
  → Agent 执行: od media generate --model custom-image
  → daemon 查 media-config.json → custom-image provider
  → GPU diffusers 服务 → 生图成功 ✓
```

### 已知限制

1. **新项目模板默认值**：从 Web UI 模板创建的新 image 项目，其 `imageModel` 默认值由模板决定（通常是 `vela/gpt-image-2`）。每次批量创建后需要重新执行上述 SQLite 更新。

2. **`byokImageModel` 全局配置不适用**：`app-config.json` 的 `byokImageModel` 字段仅在 `senseaudio`/`aihubmix` 协议下生效，Claude 协议下被清空。`ALLOWED_KEYS` 白名单也不包含此字段，CLI/API 无法写入。

3. **`aliases` 不能跨提供商重定向**：`media-config.json` 的 aliases 只改变模型名（wire-name），不改变提供商路由。将 `vela/gpt-image-2` 别名到其他模型名，仍然走 vela 提供商。

### 未来建议（需代码改动）

- 在 `media-config.json` 中增加 `"defaultImageProvider": "custom-image"` 字段
- 或在 `system.ts:575` 的兜底逻辑中读取环境变量 `OD_DEFAULT_IMAGE_MODEL`
- 或在 Settings 页面的 Custom Image API 配置中添加「设为默认图像模型」选项

---

## 10. 相关文件索引

| 文件 | 作用 |
|------|------|
| `.od/media-config.json` | 媒体提供商凭证配置 |
| `apps/daemon/src/prompts/system.ts:575` | imageModel 兜底逻辑 |
| `apps/daemon/src/prompts/system.ts:1878-1880` | 项目 imageModel 写入 prompt |
| `apps/daemon/src/prompts/media-contract.ts:504-510` | Agent 模型选择优先级指令 |
| `apps/web/src/components/ProjectView.tsx:1987-2022` | Web UI byokMediaDefaults 构建 |
| `apps/daemon/src/media/config.ts` | media-config.json 加载逻辑 |
| `apps/daemon/src/media/models.ts:42,126` | custom-image 提供商定义 |
