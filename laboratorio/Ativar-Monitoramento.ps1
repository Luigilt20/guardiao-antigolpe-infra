#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$scripts = 'C:\Program Files\CitizenTech\Scripts'
New-Item -ItemType Directory -Path $scripts -Force | Out-Null
Copy-Item "$PSScriptRoot\scripts\*.ps1" $scripts -Force
if (![System.Diagnostics.EventLog]::SourceExists('CitizenTechMonitor')) {
    New-EventLog -LogName Application -Source CitizenTechMonitor
}
& "$scripts\Configurar-PerfMon.ps1"
$inicio = (Get-Date).AddMinutes(1)
$principal = New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest
$opcoes = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
foreach ($tarefa in @(
    @{Nome='CitizenTech_Monitor_Alertas'; Arquivo='Monitor-Recursos.ps1'; Minutos=5; Argumentos=''},
    @{Nome='CitizenTech_Recuperacao'; Arquivo='Recupera-Site.ps1'; Minutos=1; Argumentos='-Url http://10.0.2.10/ -TextoEsperado Antigolpe'}
)) {
    $arg = '-NoProfile -NonInteractive -File "{0}\{1}" {2}' -f $scripts,$tarefa.Arquivo,$tarefa.Argumentos
    $acao = New-ScheduledTaskAction -Execute "$PSHOME\powershell.exe" -Argument $arg
    $gatilho = New-ScheduledTaskTrigger -Once -At $inicio -RepetitionInterval (New-TimeSpan -Minutes $tarefa.Minutos)
    Register-ScheduledTask -TaskName $tarefa.Nome -Action $acao -Trigger $gatilho -Principal $principal -Settings $opcoes -Force
}
sc.exe failure W3SVC reset= 86400 actions= restart/5000/restart/10000/restart/30000
if ($LASTEXITCODE) { throw 'Falha ao configurar recuperacao do servico.' }
sc.exe qfailure W3SVC
& "$scripts\Monitor-Recursos.ps1" -LimiteMemoriaMB 2147483647
