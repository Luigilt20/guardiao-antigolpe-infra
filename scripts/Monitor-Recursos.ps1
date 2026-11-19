# Executar no Windows Server em Windows PowerShell 5.1.
[CmdletBinding()]
param(
    [ValidateRange(0, 100)]
    [double]$LimiteCpuPercentual = 80,

    [ValidateRange(0, 2147483647)]
    [int]$LimiteMemoriaMB = 500,

    [ValidateRange(0, 2147483647)]
    [double]$LimiteDiscoGB = 15,

    [string]$Log = "$PSScriptRoot\logs\alertas.log"
)

$ErrorActionPreference = 'Stop'
$fonte = 'CitizenTechMonitor'
$cpu = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
$sistema = Get-CimInstance Win32_OperatingSystem
$disco = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"

if ($null -eq $cpu.PercentProcessorTime -or $null -eq $sistema.FreePhysicalMemory -or
    $null -eq $disco.FreeSpace) {
    throw 'Nao foi possivel coletar os tres indicadores.'
}

$usoCpu = [double]$cpu.PercentProcessorTime
$ramLivre = $sistema.FreePhysicalMemory / 1KB
$discoLivre = $disco.FreeSpace / 1GB
$indicadores = 'CPU {0:N1}% | RAM livre {1:N0} MB | Disco {2} livre {3:N2} GB' -f
    $usoCpu, $ramLivre, $env:SystemDrive, $discoLivre

$alertas = @(
    if ($usoCpu -gt $LimiteCpuPercentual) { 'CPU acima do limite' }
    if ($ramLivre -lt $LimiteMemoriaMB) { 'RAM abaixo do limite' }
    if ($discoLivre -lt $LimiteDiscoGB) { 'Disco abaixo do limite' }
)
$agora = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
if ($alertas.Count -eq 0) {
    Write-Output "$agora | OK | $indicadores"
    return
}

$mensagem = "$agora | ALERTA: $($alertas -join ', ') | $indicadores"
$arquivo = [System.IO.Path]::GetFullPath($Log)
New-Item -ItemType Directory -Path (Split-Path -Parent $arquivo) -Force | Out-Null
Add-Content -LiteralPath $arquivo -Value $mensagem -Encoding UTF8
Write-Warning $mensagem
Write-EventLog -LogName Application -Source $fonte -EventId 9001 -EntryType Warning -Message $mensagem
