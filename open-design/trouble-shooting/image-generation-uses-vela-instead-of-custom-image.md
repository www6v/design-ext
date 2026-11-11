# 故障排查：Web UI Agent 生图失败 — 使用 vela/gpt-image-2 而非 custom-image

> 日期：2026-11-11  
> 影响范围：所有 `kind=image` 类型的项目  
> 状态：已解决

---

## 问题描述

在 OpenDesign Web UI 中创建图像生成任务后，Agent（Claude Code）不使用已配置的 GPU（Custom Image API），而是选择 `vela/gpt-image-2` 模型，导致报错：

```
task failed: vela binary not found; install vela or configure VELA_BIN
```

### 现象

- Settings 页面已正确配置 Custom Image API（Base URL 指向 GPU、模型 sdxl）
- CLI 手动执行 `od media generate --model custom-image` 可以正常生图
- Web UI 中 Agent 始终选择 `vela/gpt-image-2`，忽略已配置的 GPU

---

## 根因分析

### 核心原因

**Settings 页面的「媒体生成提供商」配置只注册了提供商凭证，不影响 Agent 的模型选择逻辑。**

Agent 选择图像模型的决策链路如下（优先级从高到低）：

| 优先级 | 来源 | 本环境状态 |
|--------|------|-----------|
| 1 | 用户消息中明确指定的模型 | 无 |
| 2 | Web UI 每次对话请求携带的 `byokMediaDefaults.imageModel` | **空**（Claude 协议下被清空） |
| 3 | 项目 `metadata.imageModel`（仅当 `kind=image` 时写入 system prompt） | **NULL**（未设置） |
| 4 | **硬编码兜底值 `vela/gpt-image-2`** | ← Agent 走到这里 |

### 详细分析

**1. Settings 配置只注册凭证**

Settings 页面配置的 Custom Image API 保存到 `.od/media-config.json`，仅告诉 daemon「custom-image 这个提供商怎么连接」，但不告诉 Agent「请用 custom-image」。

**2. `byokMediaDefaults` 对 Claude 协议无效**

Web UI 的 `byokMediaDefaultsForRun()` 函数构建模型默认值时：

```typescript
// apps/web/src/components/ProjectView.tsx:1997
const imageModel = firstNonBlank(
  input.imageModelOverride,        // UI 模型覆盖 — 空
  input.config.byokImageModel,     // 全局配置 — Claude 协议下被清空为 ''
  input.imageModelOptions[0]?.id,  // 可用模型列表 — Claude 协议无对应选项
);
```

`byokImageModel` 仅对 `senseaudio`/`aihubmix` 协议生效，Claude 协议下被主动清空。

**3. 项目 `imageModel` 未设置**

从模板创建的 image 类项目，其 `metadata.imageModel` 取决于模板默认值。本环境中所有项目的 `imageModel` 都是 `vela/gpt-image-2` 或 NULL。

当 `kind=image` 但 `imageModel=NULL` 时，system prompt 显示：

```
- **imageModel**: (not provided)
```

Agent 看到 `(not provided)` 后走 media-contract 的兜底逻辑：

```
otherwise use `vela/gpt-image-2`
```

**4. 本地没有 vela binary**

`vela/gpt-image-2` 需要 vela CLI（OpenDesign 云端图像生成工具），本地环境未安装，导致失败。

---

## 解决方案

### 方案：批量更新项目 metadata

将所有 `kind=image` 的项目的 `imageModel` 设为 `custom-image`，使 Agent 在 system prompt 中看到正确的模型指令。

```bash
# 1. 备份数据库
cp .od/app.sqlite .od/app.sqlite.bak

# 2. 批量更新
sqlite3 .od/app.sqlite "
UPDATE projects
SET metadata_json = json_set(metadata_json, '$.imageModel', 'custom-image'),
    updated_at = (strftime('%s','now') * 1000)
WHERE json_extract(metadata_json, '$.kind') = 'image';
"

# 3. 重启 daemon 使改动生效
systemctl --user restart opendesign.service
```

### 验证

```bash
# 检查 API 返回正确的 imageModel
curl -s http://127.0.0.1:7456/api/projects/<PROJECT_ID> | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d['project']['metadata'].get('imageModel'))"
# 应输出: custom-image

# 测试 CLI 生图
od media generate \
  --project <PROJECT_ID> \
  --surface image \
  --model custom-image \
  --prompt "test image" \
  --output "test.png" \
  --aspect 1:1

# 检查 GPU 健康
curl -s http://<GPU_IP>:7865/health | python3 -m json.tool
```

### 修复后流程

```
system prompt  →  "imageModel: custom-image"
       ↓
media-contract →  "use project metadata's imageModel"
       ↓
Agent 执行     →  od media generate --model custom-image
       ↓
daemon 查找    →  media-config.json → custom-image provider
       ↓
GPU diffusers  →  POST /v1/images/generations → 生图成功 ✓
```

---

## 已知限制

| 限制 | 说明 |
|------|------|
| 新项目模板默认值 | 从 Web UI 模板创建的新 image 项目，`imageModel` 默认由模板决定（通常是 `vela/gpt-image-2`），需重新执行批量更新 |
| `byokImageModel` 全局配置 | 仅在 `senseaudio`/`aihubmix` 协议下生效，Claude 协议下被清空；`ALLOWED_KEYS` 白名单也不包含此字段 |
| `aliases` 不能跨提供商重定向 | `media-config.json` 的 aliases 只改变模型名（wire-name），不改变提供商路由 |

---

## 相关文件

| 文件 | 作用 |
|------|------|
| `.od/media-config.json` | 媒体提供商凭证配置 |
| `.od/app.sqlite` | 项目数据库，存储 `metadata.imageModel` |
| `apps/daemon/src/prompts/system.ts:575` | imageModel 兜底逻辑 `defaults?.imageModel?.trim() \|\| 'vela/gpt-image-2'` |
| `apps/daemon/src/prompts/system.ts:1878-1880` | 项目 imageModel 写入 system prompt（仅 kind=image） |
| `apps/daemon/src/prompts/media-contract.ts:504-510` | Agent 模型选择优先级指令 |
| `apps/web/src/components/ProjectView.tsx:1987-2022` | Web UI `byokMediaDefaultsForRun()` 构建逻辑 |
| `apps/web/src/media/models.ts:491-498` | `custom-image` 模型定义 |
| `apps/web/src/components/SettingsDialog.tsx:1165-1172` | `byokImageModel` 仅对 senseaudio/aihubmix 生效 |

---

## 未来建议（需代码改动）

1. 在 `media-config.json` 中增加 `"defaultImageProvider"` 字段，Settings 页面允许设为默认
2. 在 `system.ts:575` 兜底逻辑中读取环境变量 `OD_DEFAULT_IMAGE_MODEL`
3. Settings 页面 Custom Image API 配置中添加「设为默认图像模型」复选框
4. 模板系统创建项目时，若检测到 Custom Image API 已配置，自动使用 `custom-image` 作为 `imageModel`
