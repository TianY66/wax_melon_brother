# 网页部署说明

本文档用于说明《冬瓜兄弟》如何部署为 **itch.io 可直接在浏览器中游玩的 HTML5 版本**。

## 部署目标

- 部署平台：itch.io
- 目标用户：仅桌面浏览器
- 导出预设：`Web`
- 导出产物：`dist/web/index.html`
- 发布渠道：`html5`

## itch.io 一次性初始化

以下步骤只需要做一次，后续就可以走自动发布流程：

1. 在 itch.io 上创建一个新项目，slug 固定为 `winter-melon-brothers`
2. 项目类型选择 **HTML Game**
3. 第一次上传成功后，进入项目编辑页面，完成以下配置：
   - 页面类型：`HTML`
   - 渠道设置：将 `html5` 标记为可在浏览器中游玩
   - 嵌入方式：`Embed in page`
   - 页面尺寸：`1280 x 720`
   - `Click to Play`：开启
   - `Fullscreen Button`：开启
   - `Scrollbars`：关闭
   - `Mobile Friendly`：关闭

## GitHub 配置

1. 创建 GitHub 仓库，并把本项目推送到 `main` 分支
2. 在 GitHub Secrets 中添加：
   - `BUTLER_API_KEY`
3. 在 GitHub Variables 中添加：
   - `ITCH_TARGET` -> `username/winter-melon-brothers`
   - `ITCH_CHANNEL` -> `html5`
   - `GODOT_VERSION` -> `4.6.2`

## 本地导出命令

在本机安装好 Godot 4.6.2 对应的 Web 导出模板之后，可以使用下面的命令导出网页版本：

```powershell
& 'D:\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'E:\wax_gourd_brother' --export-release "Web" "dist/web/index.html"
```

## 本地浏览器测试

导出完成后，需要通过 HTTP 服务启动导出目录，不能直接双击 HTML 文件。

例如：

```powershell
Set-Location E:\wax_gourd_brother\dist\web
python -m http.server 8000
```

然后在浏览器中打开：

- `http://127.0.0.1:8000/index.html`

重点验证以下内容：

- 主菜单是否正常显示
- `Start Game` 是否能进入游戏
- `WASD` 是否能正常移动
- 自动攻击是否正常工作
- 升级选项是否能弹出并选择
- `Esc` 是否能暂停和恢复
- 结算界面是否能正常显示

## CI 自动发布行为

- 每次向 `main` 分支 push 都会触发 `deploy-web`
- 也可以通过 `workflow_dispatch` 手动触发发布
- 发布始终覆盖 itch.io 的同一个渠道：`html5`

## 常见问题

### 缺少导出模板

现象：

- Godot 在导出阶段失败
- `dist/web/index.html` 没有生成

解决方式：

- 确认已经安装与 `4.6.2` 对应的 Web 导出模板

### 缺少 BUTLER_API_KEY

现象：

- GitHub Actions 在校验阶段或上传阶段失败

解决方式：

- 在 GitHub Secrets 中添加 `BUTLER_API_KEY`

### 缺少 ITCH_TARGET

现象：

- GitHub Actions 在上传之前就失败

解决方式：

- 在 GitHub Variables 中添加 `ITCH_TARGET`
- 格式必须是：`username/winter-melon-brothers`

### itch.io 页面不能直接游玩

现象：

- 构建上传成功了，但 itch.io 页面没有显示浏览器内嵌游玩入口

解决方式：

- 确认页面类型设置为 `HTML`
- 确认 `html5` 渠道被标记为可在浏览器中游玩
- 确认页面启用了嵌入显示

