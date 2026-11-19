# Rodar em PowerShell elevado na VM dedicada. A tarefa agendada faz a recuperacao.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$Url,

    [Parameter(Mandatory)]
    [string]$TextoEsperado,

    [ValidateSet('Servico', 'Pool')]
    [string]$Alvo = 'Servico',

    [string]$Pool = 'CitizenTechPool',
    [string]$Tarefa = 'CitizenTech_Recuperacao',

    [ValidateRange(30, 600)]
    [int]$TempoMaximoSegundos = 150,

    [Parameter(Mandatory)]
    [switch]$SimularFalha
)

$ErrorActionPreference = 'Stop'
if (-not $SimularFalha) {
    throw 'Use -SimularFalha somente na VM dedicada.'
}

Import-Module WebAdministration
if ((Get-ScheduledTask -TaskName $Tarefa).State -notin @('Ready', 'Running')) {
    throw "A tarefa $Tarefa precisa estar ativa."
}

function TestarAplicacao {
    try {
        $resposta = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -MaximumRedirection 0
        return $resposta.StatusCode -eq 200 -and $resposta.Content.Contains($TextoEsperado)
    }
    catch {
        return $false
    }
}

function ConsultarAlvo {
    if ($Alvo -eq 'Pool') {
        return (Get-WebAppPoolState -Name $Pool).Value
    }
    return (Get-Service W3SVC).Status.ToString()
}

if (-not (TestarAplicacao) -or (ConsultarAlvo) -notin @('Running', 'Started')) {
    throw "O teste exige a CitizenTech respondendo em $Url antes da parada."
}

Write-Output "$(Get-Date -Format HH:mm:ss) [1/5] $Alvo operacional. CitizenTech HTTP 200."
Write-Output "$(Get-Date -Format HH:mm:ss) [2/5] Parada controlada de $Alvo."
if ($Alvo -eq 'Pool') {
    Stop-WebAppPool -Name $Pool
}
else {
    Stop-Service -Name W3SVC
}

$parada = [Diagnostics.Stopwatch]::StartNew()
do {
    $estado = ConsultarAlvo
    $indisponivel = $estado -in @('Stopping', 'StopPending', 'Stopped') -and -not (TestarAplicacao)
    if ($indisponivel) { break }
    Start-Sleep -Milliseconds 250
} while ($parada.Elapsed.TotalSeconds -lt 15)
if (-not $indisponivel) {
    throw 'A indisponibilidade nao foi observada. Repita logo apos a proxima rodada da tarefa.'
}
Write-Output "$(Get-Date -Format HH:mm:ss) [3/5] $Alvo $estado. Aplicacao indisponivel."
Write-Output "$(Get-Date -Format HH:mm:ss) [4/5] Aguardando a tarefa agendada."
$cronometro = [System.Diagnostics.Stopwatch]::StartNew()
do {
    Start-Sleep -Seconds 3
    $estado = ConsultarAlvo
    if ($estado -in @('Running', 'Started') -and (TestarAplicacao)) {
        Write-Output "$(Get-Date -Format HH:mm:ss) [5/5] $Alvo $estado. CitizenTech HTTP 200 apos $([int]$cronometro.Elapsed.TotalSeconds)s de espera."
        return
    }
} while ($cronometro.Elapsed.TotalSeconds -lt $TempoMaximoSegundos)

throw "A recuperacao automatica nao foi confirmada em $TempoMaximoSegundos segundos."
