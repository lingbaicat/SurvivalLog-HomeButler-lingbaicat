# 第三方组件与来源

| 组件 | 随包版本 / 来源 | 许可材料 |
|---|---|---|
| BaseButler | 2.0.12 定制适配二进制；原作者 lingxiangtingsheng | docs/AUTHORIZATION.md |
| BepInEx | 6.0.0-be.788，IL2CPP win-x64；commit 5b766a3b7f6c164d4798924a93f3acf4db769d06 | licenses/BepInEx-LICENSE.txt，LGPL-2.1 |
| Unity Doorstop | 随上述官方 BepInEx 分发包，版本标识见 payload/.doorstop_version | licenses/Doorstop-LICENSE.txt |
| .NET runtime | 6.0.7，随上述 BepInEx 分发包 | licenses/dotnet-LICENSE.txt 与 dotnet-THIRD-PARTY-NOTICES.txt |

官方分发与源码入口：

- BaseButler：https://www.nexusmods.com/survivallog/mods/4
- BepInEx 构建：https://builds.bepinex.dev/projects/bepinex_be
- BepInEx 对应源码：https://github.com/BepInEx/BepInEx/tree/5b766a3b7f6c164d4798924a93f3acf4db769d06
- Doorstop：https://github.com/NeighTools/UnityDoorstop
- .NET 6.0.7：https://github.com/dotnet/runtime/tree/v6.0.7
- Il2CppInterop：https://github.com/BepInEx/Il2CppInterop
- HarmonyX：https://github.com/BepInEx/HarmonyX
- MonoMod：https://github.com/MonoMod/MonoMod
- Cpp2IL：https://github.com/SamboyCoding/Cpp2IL

框架载荷来自未修改的官方分发文件；原始框架 ZIP 的 SHA-256 记录在 manifest 的 FrameworkArchiveSHA256。上游附带的许可和第三方声明保留在 licenses。进一步重分发或更换框架版本时，应同步其对应源码提供方式、依赖许可及声明，不能把原作授权扩展到其他组件。
