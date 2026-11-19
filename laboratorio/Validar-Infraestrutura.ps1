#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory,DnsServer,GroupPolicy,WebAdministration
$ErrorActionPreference = 'Stop'
$nome = 'srv-citizentech.citizentech.local'
$site = Get-Website -Name CitizenTech
$pasta = 'C:\ProgramData\CitizenTech\Evidencias'
New-Item -ItemType Directory -Path $pasta -Force | Out-Null
$arquivo = Join-Path $pasta ('Verificacao-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Start-Transcript -Path $arquivo
try {
    hostname.exe
    ipconfig.exe /all
    nslookup.exe $nome
    Test-NetConnection -ComputerName $nome -Port 80 | Format-List ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded
    Get-ADDomain | Format-Table Name,DNSRoot,DomainMode
    Get-DnsServerZone | Format-Table ZoneName,ZoneType
    Get-ADGroupMember GG_CitizenTech_Admins | Format-Table Name,SamAccountName
    Get-WindowsFeature Web-Server,AD-Domain-Services,DNS,FS-FileServer | Format-Table Name,InstallState
    $site | Format-List Name,State,PhysicalPath,ApplicationPool,Bindings
    Get-WebAppPoolState CitizenTechPool
    Get-Service W3SVC,DNS | Format-Table Name,Status
    Get-SmbShare -Name CitizenTech | Format-Table Name,Path
    Get-SmbShareAccess -Name CitizenTech | Format-Table AccountName,AccessRight
    Get-GPO -Name GPO_CitizenTech_Usuarios | Format-List DisplayName,GpoStatus
    Get-GPInheritance -Target 'OU=CitizenTech,DC=citizentech,DC=local' | Format-List GpoLinks
    (Get-Acl $site.PhysicalPath).Access | Format-Table IdentityReference,FileSystemRights -Wrap
    (Get-Acl 'C:\ProgramData\GuardiaoAntigolpe\Dados').Access | Format-Table IdentityReference,FileSystemRights -Wrap
    Get-ScheduledTask -TaskName 'CitizenTech_*' | Format-Table TaskName,State
    logman.exe query CitizenTech_Monitor
    logman.exe query CitizenTech_Limiares
    sc.exe qfailure W3SVC
    auditpol.exe /get /subcategory:"Logon"
    auditpol.exe /get /subcategory:"File System"
    Get-Content (Join-Path $site.PhysicalPath 'web.config') -TotalCount 1 | Out-Null
    Get-WinEvent -FilterHashtable @{LogName='Security';Id=4624,4663} -MaxEvents 6 | Format-Table TimeCreated,Id,ProviderName
    Get-WinEvent -FilterHashtable @{LogName='Application';ProviderName='CitizenTechMonitor';Id=9001} -MaxEvents 1 | Format-List TimeCreated,Id,Message
    $r = Invoke-WebRequest -UseBasicParsing -Uri "http://$nome/"
    if ($r.StatusCode -ne 200 -or !$r.Content.Contains('Antigolpe')) { throw 'Conteudo do painel nao confirmado.' }
    Write-Output "Guardiao Antigolpe HTTP $($r.StatusCode)"
    netsh.exe http flush logbuffer
    $logDir = [Environment]::ExpandEnvironmentVariables($site.logFile.directory)
    $log = Get-ChildItem (Join-Path $logDir "W3SVC$($site.Id)") -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($log) { Get-Content $log.FullName -Tail 5 }
} finally { Stop-Transcript }
