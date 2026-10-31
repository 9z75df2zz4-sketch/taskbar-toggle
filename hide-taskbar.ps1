$ErrorActionPreference = 'Stop'

# Local named handles allow one instance per Windows session, across copies.
$mutex = New-Object System.Threading.Mutex($false, 'Local\HideTaskbar')
$ownsMutex = $false
$stopEvent = $null
$originalState = $null

try {
    try {
        $ownsMutex = $mutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $ownsMutex = $true
    }
    if (-not $ownsMutex) { return }

    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Taskbar {
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hWnd, uint attr, ref int value, int size);
    [StructLayout(LayoutKind.Sequential)]
    public struct APPBARDATA {
        public int cbSize;
        public IntPtr hWnd;
        public uint uCallbackMessage;
        public uint uEdge;
        public RECT rc;
        public IntPtr lParam;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("shell32.dll")] public static extern uint SHAppBarMessage(uint dwMessage, ref APPBARDATA pData);
}
"@

    function New-AppBarData {
        $abd = New-Object 'Taskbar+APPBARDATA'
        $abd.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($abd)
        $abd.hWnd = [Taskbar]::FindWindow('Shell_TrayWnd', $null)
        return $abd
    }

    function Set-TaskbarState([uint32]$state) {
        $abd = New-AppBarData
        $abd.lParam = [IntPtr]$state
        [void][Taskbar]::SHAppBarMessage(10, [ref]$abd)
    }

    function Set-TaskbarVisibility([bool]$visible) {
        foreach ($cls in @('Shell_TrayWnd', 'Shell_SecondaryTrayWnd')) {
            $h = [IntPtr]::Zero
            while (($h = [Taskbar]::FindWindowEx([IntPtr]::Zero, $h, $cls, $null)) -ne [IntPtr]::Zero) {
                $cloak = if ($visible) { 0 } else { 1 }
                [void][Taskbar]::DwmSetWindowAttribute($h, 13, [ref]$cloak, 4)
                [void][Taskbar]::ShowWindow($h, $(if ($visible) { 5 } else { 0 }))
            }
        }
    }

    $abd = New-AppBarData
    if ($abd.hWnd -eq [IntPtr]::Zero) { throw 'The Windows Explorer taskbar was not found.' }
    $originalState = [Taskbar]::SHAppBarMessage(4, [ref]$abd)
    $stopEvent = New-Object System.Threading.EventWaitHandle(
        $false, [System.Threading.EventResetMode]::ManualReset, 'Local\HideTaskbar.Stop'
    )

    Set-TaskbarState ($originalState -bor 1)
    Set-TaskbarVisibility $false
    $shown = $false
    $f1Held = $false

    while (-not $stopEvent.WaitOne(50)) {
        $shiftDown = ([Taskbar]::GetAsyncKeyState(0x10) -band 0x8000) -ne 0
        $f1Down    = ([Taskbar]::GetAsyncKeyState(0x70) -band 0x8000) -ne 0
        $ctrlDown  = ([Taskbar]::GetAsyncKeyState(0x11) -band 0x8000) -ne 0
        $altDown   = ([Taskbar]::GetAsyncKeyState(0x12) -band 0x8000) -ne 0
        $qDown     = ([Taskbar]::GetAsyncKeyState(0x51) -band 0x8000) -ne 0

        $f1Combo = $shiftDown -and $f1Down
        if ($f1Combo -and -not $f1Held) {
            $shown = -not $shown
            if ($shown) {
                Set-TaskbarState ($originalState -band 0xFFFFFFFE)
                Set-TaskbarVisibility $true
            } else {
                Set-TaskbarState ($originalState -bor 1)
                Set-TaskbarVisibility $false
            }
        }
        $f1Held = $f1Combo

        if ($ctrlDown -and $altDown -and $qDown) { break }
        if (-not $shown) { Set-TaskbarVisibility $false }
    }
} finally {
    if ($null -ne $originalState) {
        Set-TaskbarVisibility $true
        Set-TaskbarState $originalState
    }
    if ($null -ne $stopEvent) { $stopEvent.Dispose() }
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}