# Survival Log 居家管家兼容整合包

**HomeButler 1.0.0 · Steam Windows x64 · 游戏 1.1.18385**

由 [lingbaicat](https://github.com/lingbaicat) 维护的 BaseButler 授权适配整合包，提供家中容器访问、取料与堆叠辅助，并修复新版游戏中背包面板偏移、容器标签撑宽和切换后不可见的问题。

[下载玩家安装包](https://github.com/lingbaicat/SurvivalLog-HomeButler-lingbaicat/releases/latest) · [安装与卸载](docs/INSTALL.md) · [配置与按键](docs/CONFIGURATION.md) · [常见问题](docs/TROUBLESHOOTING.md) · [反馈问题](https://github.com/lingbaicat/SurvivalLog-HomeButler-lingbaicat/issues)

## 下载和安装

请在 Releases 的 **Assets** 中下载 `SurvivalLog-HomeButler-1.0.0-Game1.1.18385-win-x64.zip`。GitHub 自动提供的 **Source code** 是维护文件，不是玩家安装包。

1. 退出游戏，在 Steam 中选择“管理 → 浏览本地文件”。
2. 将安装包内全部内容解压到 `SurvivalLog.exe` 所在目录，不要再套一层文件夹。
3. 双击 `Install.cmd`，看到 `Installed successfully` 后，从 Steam 启动游戏。

首次启动需要联网生成 BepInEx 接口，可能等待数分钟。安装后保留 `HomeButler-Package` 文件夹，其中保存卸载恢复记录。

## 主要功能

- 家中背包、货舱及适用容器显示储物来源标签，减少来回开柜。
- 标签栏可横向滚动；单背包、双容器和大容量容器按当前尺寸居中。
- 切换后选中标签保持可见，隐藏标签的拖放区域随滚动更新。
- 保留材料堆叠、自动合并、后台取料和工作台按量取料兼容功能。
- `Shift + 右键` 拆半，`Tab + 右键` 转移一个；燃料来源用 `PageUp / PageDown` 切换。

## 适配范围和限制

仅适配 **Steam Windows x64 / Survival Log 1.1.18385** 的已测试构建，安装器同时校验关键文件指纹。不同版本、不同加载器或已被其他模组修改的界面可能无法叠加安装。

`Q` 丢弃“只丢一个”在本定制版本中未可靠生效，请按游戏实际提示操作。材料规则可能将命中物品的堆叠上限设为 5；可在配置中调整。卸载不会回退游玩产生的存档变化。

游戏更新前先卸载本包；更新后等待对应适配版。安装器的版本检查不会在每次启动游戏时自动停用旧插件。

## 版本与验证

包版本号与原 BaseButler 版本独立。本包包含 BaseButler 定制适配版 2.0.12、NativeCompatibility 2.0.5、HomeAccess 1.0.6，以及 BepInEx 6.0.0-be.788。

维护者已确认取得原作者授权，并已在多台电脑上测试通过。离线布局、接口检查及安装器测试记录见 [验证说明](docs/VALIDATION.md)。多机测试未提供逐机环境表，因此不扩大声明为所有系统或所有游戏版本均兼容。

## 署名和许可

BaseButler 原作者：[lingxiangtingsheng](https://www.nexusmods.com/survivallog/mods/4)。本项目由 lingbaicat 维护适配与发布，不代表原作者或游戏官方发布。

本项目免费发布。原作、兼容插件、框架和第三方依赖分别适用各自权利与许可；本仓库公开两个兼容插件源码，未提供 BaseButler 定制二进制的完整源码构建链，**不声明整个整合包为完整开源项目**。详见 [授权与致谢](docs/AUTHORIZATION.md) 和 [第三方说明](THIRD-PARTY-NOTICES.md)。

开发与文档整理使用了 AI 辅助；功能测试由维护者完成。提交问题时请提供游戏版本、包版本、复现步骤及经过隐私检查的日志。
