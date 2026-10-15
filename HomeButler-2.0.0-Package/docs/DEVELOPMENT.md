# 构建与维护

安装 .NET 6 SDK，运行当前游戏生成 BepInEx/interop。对 source/HomeAccess.csproj、source/Compatibility.csproj、source/Navigation/Navigation.csproj、source/InlineEditor/InlineEditor.csproj 使用：

```powershell
dotnet build <项目路径> -c Release "-p:GameDir=<游戏根目录>"
```

发布 DLL 保留用户实测通过的二进制；安装器只在用户目录基于现有页面应用变换，不打包游戏 HTML。InlineEditor 使用与 DLL 相同的 UTF-8 JavaScript，安装器变换须与 DLL 启动时结果一致，否则 Check 会报告变化。

运行 *.test.cjs 需要 Node.js 和 Playwright 浏览器（InlineEditor），Navigation 测试仅需 Node.js。参考接口检查使用 source/Check-References.ps1，需游戏目录的 Mono.Cecil 和 interop；动态反射与未来版本兼容性不能靠引用检查保证。

更改源码/二进制/安装器后，更新 manifest.json 的 PackageFiles 哈希和新组件 Payload。发布脚本源及验证日志在维护资料中。不要将测试目录里的游戏资源、任何 interop、.state、存档、个人标签和日志提交到 GitHub。
