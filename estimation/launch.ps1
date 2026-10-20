# launch.ps1  Start one detached MATLAB batch process of the estimation module.
#
#   powershell -File launch.ps1 -Cmd "est_05_mcmc_learn(1, 60000)" -Log "mcmc_learn_1.txt"
#
# Runs `cd('<this folder>'); <Cmd>` with matlab -batch in a hidden window, log in
# results\estimation\logs\<Log>. Prints the launcher's process id; the MATLAB worker's own
# pid is written by hlest.rwmh into each chain's progress.txt (see est_status).
param(
    [Parameter(Mandatory = $true)][string]$Cmd,
    [Parameter(Mandatory = $true)][string]$Log
)
$est = Split-Path -Parent $MyInvocation.MyCommand.Path
$logs = Join-Path (Split-Path -Parent $est) "results\estimation\logs"
if (-not (Test-Path $logs)) { New-Item -ItemType Directory -Force $logs | Out-Null }
$exe = "C:\Program Files\MATLAB\R2025a\bin\matlab.exe"
$batch = "`"cd('$est'); $Cmd`""
$p = Start-Process -FilePath $exe -ArgumentList @('-batch', $batch, '-logfile', "`"$logs\$Log`"") -PassThru -WindowStyle Hidden
"{0}  {1}  {2}" -f $p.Id, (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Cmd
