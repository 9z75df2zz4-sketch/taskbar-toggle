# Taskbar Toggle · 完全隐藏任务栏

一键将 Windows 任务栏完全隐藏，隐藏后鼠标移到屏幕边缘也不会唤出。再次双击恢复，或用快捷键临时显示、隐藏及退出。

A small Windows desktop utility to completely hide the taskbar, including when the pointer reaches the screen edge. Double-click again to restore it, or use hotkeys for temporary display and exit. Built with PowerShell and VBScript; no third-party packages or administrator rights required on a standard Windows desktop.

## 下载与使用 / Quick start

1. 点击仓库右上方 **Code → Download ZIP**，解压整个文件夹。
2. 双击 **`任务栏开关.vbs`**，隐藏任务栏。
3. 再双击同一文件，退出并恢复任务栏及启动前的“自动隐藏”设置。

Download the ZIP from **Code → Download ZIP**, extract all files, then double-click **`任务栏开关.vbs`** to toggle. Keep the scripts together; the extracted folder can be moved.

| 操作 / Action | 快捷键 / Shortcut |
| --- | --- |
| 临时显示 / 再次隐藏 · Temporarily show / hide | **Shift + F1** |
| 退出并恢复 · Exit and restore | **Ctrl + Alt + Q** |

隐藏期间，程序会定期隐藏并遮蔽主任务栏和扩展屏任务栏，同时临时启用系统自动隐藏，释放任务栏占用的屏幕区域。Win 键、Alt + Tab 等快捷键仍交由 Windows 处理。临时显示不会退出程序。

While hidden, the utility repeatedly hides and cloaks taskbar windows and temporarily enables auto-hide. Temporary display keeps the utility running. Only one instance runs per Windows session.

## 环境 / Requirements

- Windows 桌面、Explorer 任务栏、Windows PowerShell 5.1、Windows Script Host / VBScript。
- 面向 Windows 10 / 11。已在 Windows 11 上进行本机检查；尚未验证所有版本、显示器配置或第三方任务栏。
- VBScript 在部分 Windows 版本中可能需要作为可选功能启用；企业策略也可能限制脚本运行。

If VBScript is unavailable, use Windows PowerShell directly from the extracted folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ".\toggle-taskbar.ps1"
```

再次执行同一命令即可退出。`ExecutionPolicy Bypass` 只用于该进程，不修改持久执行策略。

## 开机自启 / Start at sign-in

按 **Win + R**，输入 `shell:startup`。在打开的文件夹中创建指向解压目录内 **`hide-taskbar.vbs` 的快捷方式**。删除该快捷方式即可取消自启。移动程序目录后，需要更新快捷方式。

Create a **shortcut to `hide-taskbar.vbs`** inside `shell:startup`. Do not copy the launcher alone: it needs its neighboring PowerShell script. Remove the shortcut to disable startup.

## 恢复与卸载 / Recovery and removal

正常退出：按 **Ctrl + Alt + Q**，或再次双击 `任务栏开关.vbs`。退出后删除解压目录和你创建的自启快捷方式即可卸载。

正常退出和可处理的脚本异常会恢复任务栏及原来的自动隐藏设置。任务管理器强制终止进程、断电或 Explorer 异常可能绕过清理；此时重新启动工具，再正常退出，以恢复可见性，并在 Windows 的“个性化 → 任务栏 → 任务栏行为”中核对自动隐藏设置。

Normal exit restores the taskbar and its saved settings. Forced process termination or a shell crash can bypass cleanup. Relaunch and exit normally to restore visibility, then check the Windows taskbar auto-hide setting if needed.

## 文件 / Files

- `任务栏开关.vbs`：一键开关入口 / double-click toggle launcher。
- `toggle-taskbar.ps1`：启动程序，或请求现有实例正常退出 / start or request a graceful exit。
- `hide-taskbar.vbs`：只启动隐藏模式，供自启快捷方式使用 / start-only launcher。
- `hide-taskbar.ps1`：任务栏控制与快捷键循环 / taskbar control and hotkeys。
- `tests/smoke.ps1`：本机功能检查 / local desktop smoke check。

## 验证 / Check

先退出正在运行的工具。在 Windows PowerShell 5.1 中进入解压目录，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\smoke.ps1"
```

检查会短暂隐藏任务栏，分别验证启动前自动隐藏开启、关闭时的启动、隐藏、退出和设置恢复。它需要可交互的 Windows 桌面，不适合无桌面的 CI。

The check briefly hides the taskbar and verifies restoration with auto-hide initially both off and on. It requires an interactive Windows desktop.
