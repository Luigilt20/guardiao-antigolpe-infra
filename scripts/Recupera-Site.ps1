# Chamado periodicamente pelo Agendador de Tarefas no Windows Server.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$Url,

    [Parameter(Mandatory)]
    [string]$TextoEsperado,

    [string]$Site = 'CitizenTech',
    [string]$Pool = 'CitizenTechPool',
    [string]$Log
)

$ErrorActionPreference = 'Stop'
if (!$Log) { $Log = Join-Path $PSScriptRoot 'logs\recuperacao.log' }
$arquivo = [System.IO.Path]::GetFullPath($Log)
New-Item -ItemType Directory -Path (Split-Path -Parent $arquivo) -Force | Out-Null

function Registrar([string]$Mensagem) {
    $linha = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $Mensagem"
    Add-Content -LiteralPath $arquivo -Value $linha -Encoding UTF8
    Write-Output $linha
}

try {
    Import-Module WebAdministration

    if ((Get-Service W3SVC).Status -ne 'Running') {
        Registrar 'Iniciando W3SVC.'
        Start-Service W3SVC
    }
    if ((Get-WebAppPoolState -Name $Pool).Value -ne 'Started') {
        Registrar "Iniciando pool $Pool."
        Start-WebAppPool -Name $Pool
    }
    $estadoSite = Get-Website -Name $Site
    if (-not $estadoSite) {
        throw "Site $Site nao encontrado."
    }
    if ($estadoSite.State -ne 'Started') {
        Registrar "Iniciando site $Site."
        Start-Website -Name $Site
    }

    $resposta = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 15 -MaximumRedirection 0
    if ($resposta.StatusCode -ne 200 -or -not $resposta.Content.Contains($TextoEsperado)) {
        throw "Resposta inesperada em $Url."
    }
    Registrar "OK HTTP 200 | $Url | Conteudo da CitizenTech confirmado."
}
catch {
    Registrar "FALHA | $($_.Exception.Message)"
    throw
}
