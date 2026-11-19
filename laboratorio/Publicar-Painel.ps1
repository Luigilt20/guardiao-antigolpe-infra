#Requires -RunAsAdministrator
#Requires -Version 5.1
param([string]$Midia = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
Import-Module WebAdministration
$raiz = 'C:\inetpub\citizentech'
$dados = 'C:\ProgramData\GuardiaoAntigolpe\Dados'
$pool = 'CitizenTechPool'
$site = 'CitizenTech'
if (!(Test-Path (Join-Path $Midia 'site\web.config'))) { throw 'Publicacao ausente na midia.' }
$instalador = Join-Path $Midia 'hosting.exe'
if ((Get-FileHash $instalador -Algorithm SHA512).Hash -ne '48dd82516cae1296fe8e6e6c0fbeb4a00033951966373bc1e8309ecd1e02f9f344db701dadb2344568d7ae86ef968439a4708fef5df3cf742d207cf585b5bf5e') { throw 'Hash inesperado do Hosting Bundle 10.0.15.' }
$instalacao = Start-Process $instalador -ArgumentList '/install /quiet /norestart' -PassThru -Wait
if ($instalacao.ExitCode -notin @(0,3010)) { throw "Instalador retornou $($instalacao.ExitCode)." }
if ($instalacao.ExitCode -eq 3010) { Write-Warning 'O instalador solicitou reinicio.' }
iisreset.exe /restart
if ($LASTEXITCODE) { throw 'Falha ao reiniciar IIS.' }
if (!(Test-Path "IIS:\AppPools\$pool")) { New-WebAppPool $pool | Out-Null }
Set-ItemProperty "IIS:\AppPools\$pool" managedRuntimeVersion ''
if ((Get-WebAppPoolState $pool).Value -eq 'Started') { Stop-WebAppPool $pool }
$espera = [Diagnostics.Stopwatch]::StartNew()
while ((Get-WebAppPoolState $pool).Value -eq 'Stopping' -and $espera.Elapsed.TotalSeconds -lt 30) { Start-Sleep -Milliseconds 250 }
if ((Get-WebAppPoolState $pool).Value -ne 'Stopped') { throw 'O pool nao parou para receber a publicacao.' }
New-Item -ItemType Directory -Path $raiz,$dados -Force | Out-Null
Copy-Item (Join-Path $Midia 'site\*') $raiz -Recurse -Force
$arquivo = Join-Path $raiz 'web.config'
(Get-Item $arquivo).IsReadOnly = $false
[xml]$config = Get-Content $arquivo -Raw
$core = $config.SelectSingleNode('//aspNetCore')
$variaveis = $config.CreateElement('environmentVariables')
$variavel = $config.CreateElement('environmentVariable')
$variavel.SetAttribute('name','GUARDIAO_DADOS')
$variavel.SetAttribute('value',$dados)
$null = $variaveis.AppendChild($variavel)
$null = $core.AppendChild($variaveis)
$config.Save($arquivo)
icacls.exe $raiz /grant "IIS AppPool\${pool}:(OI)(CI)RX"
if ($LASTEXITCODE) { throw 'Falha na permissao de leitura.' }
icacls.exe $dados /grant "IIS AppPool\${pool}:(OI)(CI)M"
if ($LASTEXITCODE) { throw 'Falha na permissao do banco.' }
if (!(Get-Website -Name $site)) {
    New-Website -Name $site -Port 80 -IPAddress '10.0.2.10' -PhysicalPath $raiz -ApplicationPool $pool | Out-Null
}
if ((Get-WebAppPoolState $pool).Value -ne 'Started') { Start-WebAppPool $pool }
Start-Website $site
Get-Website -Name $site | Format-List Name,State,PhysicalPath,ApplicationPool,Bindings
Get-WebAppPoolState $pool
$r = Invoke-WebRequest 'http://10.0.2.10/' -UseBasicParsing -TimeoutSec 60
if ($r.StatusCode -ne 200 -or !$r.Content.Contains('Antigolpe')) { throw 'Painel nao confirmado.' }
Write-Output "Guardiao Antigolpe HTTP $($r.StatusCode)"
