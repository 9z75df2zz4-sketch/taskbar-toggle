# Run with Windows PowerShell 5.1 on a desktop, with the utility stopped.
# This briefly hides the taskbar and verifies both original auto-hide settings.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

foreach ($file in Get-ChildItem -LiteralPath $repoRoot -Filter '*.ps1') {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}

try {
    $active = [System.Threading.EventWaitHandle]::OpenExisting('Local\HideTaskbar.Stop')
    $active.Dispose()
    throw 'Stop the existing taskbar utility before running this check.'
} catch [System.Threading.WaitHandleCannotBeOpenedException] { }

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class TaskbarSmoke {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct APPBARDATA {
        public int cbSize; public IntPtr hWnd; public uint callback; public uint edge; public RECT rect; public IntPtr lParam;
    }
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, uint attr, out int value, int size);
    [DllImport("shell32.dll")] public static extern uint SHAppBarMessage(uint message, ref APPBARDATA data);
}
"@

function Get-Taskbars {
    foreach ($class in @('Shell_TrayWnd', 'Shell_SecondaryTrayWnd')) {
        $handle = [IntPtr]::Zero
        while (($handle = [TaskbarSmoke]::FindWindowEx([IntPtr]::Zero, $handle, $class, $null)) -ne [IntPtr]::Zero) { $handle }
    }
}
function Get-State {
    $data = New-Object 'TaskbarSmoke+APPBARDATA'
    $data.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($data)
    [TaskbarSmoke]::SHAppBarMessage(4, [ref]$data)
}
function Set-State([uint32]$state) {
    $data = New-Object 'TaskbarSmoke+APPBARDATA'
    $data.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($data)
    $data.lParam = [IntPtr]$state
    [void][TaskbarSmoke]::SHAppBarMessage(10, [ref]$data)
}
function Test-Running {
    try {
        $handle = [Threading.EventWaitHandle]::OpenExisting('Local\HideTaskbar.Stop')
        $handle.Dispose()
        return $true
    } catch [Threading.WaitHandleCannotBeOpenedException] { return $false }
}
function Wait-For([scriptblock]$condition) {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        if (& $condition) { return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Timed out waiting for the taskbar utility.'
}
function Invoke-Toggle {
    $entry = Join-Path $repoRoot '任务栏开关.vbs'
    Start-Process -FilePath wscript.exe -WindowStyle Hidden -ArgumentList ('"{0}"' -f $entry)
}
function Test-Visibility([bool]$expected) {
    foreach ($handle in Get-Taskbars) {
        $cloak = 0
        if ([TaskbarSmoke]::DwmGetWindowAttribute($handle, 14, [ref]$cloak, 4) -ne 0) { throw 'Cannot read taskbar cloak state.' }
        $isVisible = [TaskbarSmoke]::IsWindowVisible($handle) -and ($cloak -eq 0)
        if ($isVisible -ne $expected) { return $false }
    }
    return $true
}

if (@(Get-Taskbars).Count -eq 0) { throw 'No Windows taskbar found.' }
$savedState = Get-State
try {
    foreach ($autoHide in @($false, $true)) {
        $baseline = if ($autoHide) { $savedState -bor 1 } else { $savedState -band 0xFFFFFFFE }
        Set-State $baseline
        Invoke-Toggle
        Wait-For { (Test-Running) -and (Test-Visibility $false) }
        if (((Get-State) -band 1) -ne 1) { throw 'Auto-hide was not enabled while hidden.' }
        Invoke-Toggle
        Wait-For { -not (Test-Running) }
        if (-not (Test-Visibility $true)) { throw 'A taskbar remained hidden or cloaked after exit.' }
        if ((Get-State) -ne $baseline) { throw 'The original taskbar settings were not restored.' }
        Write-Output ('PASS: start / hide / stop / restore; original auto-hide = ' + $autoHide)
    }
} finally {
    if (Test-Running) {
        $handle = [Threading.EventWaitHandle]::OpenExisting('Local\HideTaskbar.Stop')
        [void]$handle.Set()
        $handle.Dispose()
        Wait-For { -not (Test-Running) }
    }
    Set-State $savedState
}