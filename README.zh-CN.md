# Lönn Visual Previews

[English](README.md) | 简体中文

为 Lönn 的素材列表添加图块图标、decal 悬浮预览与实体悬浮预览。
这是纯 Lua 编辑器插件，无需 DLL 或重新构建 Lönn。

## 功能

- **Tile icons**：在 FG/BG 图块名称前显示 3×3 图块预览，保留收藏星标。
- **Decal previews**：鼠标在 FG/BG decal 上悬停后显示贴图与像素尺寸。
- **Entity previews**：鼠标在实体列表条目上悬停后，显示该 placement 默认属性下的静态缩略图。
- **Preview delay**：自由调整 decal 与实体预览共用的出现延迟，也可设为立即显示。

预览尺寸适应 UI 字号，棋盘格用于展示透明区域，弹窗自动适应窗口边界。
移开鼠标、切换列表、拖动或关闭对应开关后隐藏。弹窗不会拦截鼠标事件，
列表的搜索、选择、描述提示和收藏功能保持可用。

## 安装

从 [GameBanana](https://gamebanana.com/tools/24712) 下载发行 ZIP。

当前版本：**0.3.2**。已在 **Lönn 1.0.10（OlympUI）** 上验证。

1. 将发行包 `LoennVisualPreviews.zip` 放入 Celeste 的 `Mods/` 目录，无需解压。
   开发时也可使用 `Mods/LoennVisualPreviews/` 文件夹，文件夹内应直接包含 `everest.yaml` 和 `Loenn/`。
2. 重启 Lönn。

同一插件只保留 ZIP 或文件夹中的一种安装方式，避免重复加载。

## 设置

打开 **Settings → Editor → Visual previews**：

| 选项 | 默认值 | 作用 |
| --- | --- | --- |
| Tile icons | 开启 | 显示 FG/BG 图块图标 |
| Decal previews | 开启 | 显示 decal 悬浮预览 |
| Entity previews | 开启 | 显示实体悬浮预览 |
| Preview delay (seconds) | 0.35 | decal 和实体预览共用的出现延迟，单位为秒 |

延迟可输入任意非负的有限数值，填 **0** 表示无延迟。
空值、负数和非数值会标红，并继续使用上次有效设置。

所有设置即时生效并自动保存，无需点击原有的 **Save changes** 按钮。
配置保存在 Lönn 配置目录的 `Plugins/LoennVisualPreviews/settings.conf`。

## 预览行为与限制

实体使用 Lönn 已注册的渲染器，支持贴图、多 sprite、矩形以及自定义 `draw`。
它复制 placement 默认属性与当前选中房间，补齐必需节点，并生成静态缩略图，
不会向地图放置实体。没有选中房间时使用空白预览房间。节点连线及特效以
实体自身的渲染器为准；某些依赖运行时、选择状态或特殊上下文的实体可能与游戏内效果不同。
无法生成缩略图时显示 **Preview unavailable**，列表仍可正常使用。

实体缩略图按需生成，画布最大 512×512，切换悬浮目标时释放。
decal 按需加载并复用 Lönn atlas 缓存，动画 decal 显示列表对应的静态帧。
图块预览采用固定变体，兼容当前地图的原版及自定义 tileset。

插件包装 Tools 窗口与 UI 绘制函数；后续 Lönn UI 更新或其他插件替换这些函数时可能需要适配。

## 开发

在插件根目录运行 `python3 scripts/check.py`。
目录布局与本地集成检查见[开发说明（英文）](docs/development.md)。
