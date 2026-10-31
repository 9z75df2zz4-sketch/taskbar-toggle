$ErrorActionPreference = 'Stop'

# Ask the running instance to exit so its finally block restores the taskbar.
try {
    $stopEvent = [System.Threading.EventWaitHandle]::OpenExisting('Local\HideTaskbar.Stop')
} catch [System.Threading.WaitHandleCannotBeOpenedException] {
    $powershellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $scriptPath = Join-Path $PSScriptRoot 'hide-taskbar.ps1'
    Start-Process -FilePath $powershellPath -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
        '-File', ('"{0}"' -f $scriptPath)
    )
    return
}

try {
    [void]$stopEvent.Set()
} finally {
    $stopEvent.Dispose()
}