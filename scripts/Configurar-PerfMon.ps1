#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$Cpu = '\Processor(_Total)\% Processor Time',
    [string]$Memoria = '\Memory\Available MBytes',
    [string]$Disco = "\LogicalDisk($env:SystemDrive)\Free Megabytes"
)

$ErrorActionPreference = 'Stop'
# Nomes padrao para a ISO em ingles. Get-Counter valida os nomes antes de criar os conjuntos.
Get-Counter -Counter @($Cpu, $Memoria, $Disco) -MaxSamples 1 | Out-Null
$pasta = Join-Path $env:SystemDrive 'PerfLogs\CitizenTech'
New-Item -Path $pasta -ItemType Directory -Force | Out-Null

function Iniciar-Coleta([string]$Nome, [string[]]$Definicao) {
    & cmd.exe /d /c "logman.exe query $Nome >nul 2>&1"
    if ($LASTEXITCODE -ne 0) {
        & logman.exe @Definicao
        if ($LASTEXITCODE -ne 0) { throw "Falha ao criar $Nome." }
    }
    $conjunto = New-Object -ComObject Pla.DataCollectorSet
    $conjunto.Query($Nome, $null)
    if ($conjunto.Status -eq 0) { $conjunto.Start($true) }
    & logman.exe query $Nome
    if ($LASTEXITCODE -ne 0) { throw "Falha ao consultar $Nome." }
}

Iniciar-Coleta 'CitizenTech_Monitor' @(
    'create', 'counter', 'CitizenTech_Monitor', '-c', $Cpu, $Memoria, $Disco,
    '-si', '00:00:15', '-f', 'bincirc', '-max', '64', '-v', 'nnnnnn',
    '-o', (Join-Path $pasta 'Recursos')
)
Iniciar-Coleta 'CitizenTech_Limiares' @(
    'create', 'alert', 'CitizenTech_Limiares', '-th',
    ("${Cpu}>80"), ("${Memoria}<500"), ("${Disco}<15360"), '-el', '-si', '00:00:15'
)
