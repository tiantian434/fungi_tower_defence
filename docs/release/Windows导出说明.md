# Windows 参赛包

版本为 `0.1.0-jam`，导出预设为 `Windows Release`，目标为 Windows x86_64。默认生成 `exports/Windows/Huisheng.exe` 和同名 `.pck`，发布时两者必须在同一个文件夹内。

## 导出

在 Godot 4.7.2 中打开工程，等待资源导入完成，选择“项目 → 导出 → Windows Release”，使用“导出项目”并关闭“调试导出”。也可以在工程根目录运行：

```powershell
$godotReleaseTool = 'C:/Users/Iris/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force -Path './exports/Windows' | Out-Null
& $godotReleaseTool --headless --path . --export-release 'Windows Release' './exports/Windows/Huisheng.exe'
```

当前电脑的匹配模板安装在 `%APPDATA%/Godot/export_templates/4.7.2.stable/`；预设使用 Godot 的标准模板查找方式，没有把本机绝对模板路径写进仓库。

图标采用工程自己的 `icon.svg`。项目版本允许文字后缀；Windows 文件属性使用四段数字版本 `0.1.0.0`。发布程序不附带控制台窗口。

## 包内容

预设保留所有游戏资源，包含按字符串动态读取的剧情、手绘按钮和纹理；排除测试、临时输出、开发文档、原始免费素材包及构建产物。第一关仍继承部分旧演示场景，因此没有按名字批量删除 `demo` 场景；开发入口应由运行逻辑关闭。实际引用的音效已集中复制到 `assets/audio/`，原有来源与许可记录随包保留。

将 `README玩家说明.md` 复制为发布文件夹中的 `游玩说明.md`。打包整个发布文件夹，不要上传工程目录、缓存或测试文件。

## 发布验收

1. 从发布文件夹启动程序，确认不依赖 Godot 编辑器。
2. 从标题进入第一章，测试剧情、工具按钮、音量、窗口与全屏切换。
3. 覆盖三关、结算、下一章和返回标题；单独检查动态加载的手绘按钮和过场图片。
4. 静音后退出并重启，确认解除静音恢复之前选择的音量；确认章节进度可读取。
5. 把压缩包解压到一个新的文件夹再启动，最好由另一台 Windows 电脑复验。

这些步骤是验收要求，不代表已经完成。测试记录以本次实际运行日志为准。

导出设置参考：[Godot 官方 Windows 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)。
