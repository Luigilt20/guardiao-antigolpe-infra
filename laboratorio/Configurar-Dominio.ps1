#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory,GroupPolicy
$ErrorActionPreference = 'Stop'
$dominio = Get-ADDomain
if ($dominio.DNSRoot -ne 'citizentech.local') { throw 'Dominio inesperado.' }
$placa = Get-NetIPAddress -IPAddress '10.0.2.10' -AddressFamily IPv4
Set-DnsClientServerAddress -InterfaceIndex $placa.InterfaceIndex -ServerAddresses '10.0.2.10'
$reversa = '2.0.10.in-addr.arpa'
if (!(Get-DnsServerZone -Name $reversa -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId '10.0.2.0/24' -ReplicationScope Domain
}
if (!(Get-DnsServerResourceRecord -ZoneName $reversa -Name '10' -RRType Ptr -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordPtr -ZoneName $reversa -Name '10' -PtrDomainName 'srv-citizentech.citizentech.local.'
}
$ou = "OU=CitizenTech,$($dominio.DistinguishedName)"
if (!(Get-ADOrganizationalUnit -Filter "Name -eq 'CitizenTech'" -SearchBase $dominio.DistinguishedName -SearchScope OneLevel)) {
    New-ADOrganizationalUnit -Name CitizenTech -Path $dominio.DistinguishedName
}
$grupo = 'GG_CitizenTech_Admins'
if (!(Get-ADGroup -Filter "SamAccountName -eq '$grupo'")) {
    New-ADGroup -Name $grupo -GroupScope Global -GroupCategory Security -Path $ou
}
if (!(Get-ADUser -Filter "SamAccountName -eq 'ana.souza'")) {
    $senha = Read-Host 'Senha da conta de demonstracao ana.souza' -AsSecureString
    New-ADUser -Name 'Ana Souza' -SamAccountName 'ana.souza' -UserPrincipalName 'ana.souza@citizentech.local' -Path $ou -AccountPassword $senha -Enabled $true
}
Add-ADGroupMember $grupo -Members 'ana.souza'
$gpo = 'GPO_CitizenTech_Usuarios'
if (!(Get-GPO -Name $gpo -ErrorAction SilentlyContinue)) { New-GPO $gpo | Out-Null }
if ((Get-GPInheritance -Target $ou).GpoLinks.DisplayName -notcontains $gpo) { New-GPLink -Name $gpo -Target $ou | Out-Null }
Set-GPRegistryValue -Name $gpo -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -ValueName NoControlPanel -Type DWord -Value 1
$pasta = 'C:\Shares\CitizenTech'
New-Item -ItemType Directory -Path $pasta -Force | Out-Null
$leitores = (Get-ADGroup -Identity "$($dominio.DomainSID)-513").SamAccountName
icacls.exe $pasta /grant "CITIZENTECH\${grupo}:(OI)(CI)F" "CITIZENTECH\${leitores}:(OI)(CI)RX"
if ($LASTEXITCODE) { throw 'Falha na ACL do compartilhamento.' }
if (!(Get-SmbShare -Name CitizenTech -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name CitizenTech -Path $pasta -FullAccess "CITIZENTECH\$grupo" -ReadAccess "CITIZENTECH\$leitores"
}
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
Add-ADGroupMember -Identity 'S-1-5-32-555' -Members 'ana.souza'
# No controlador usado como laboratório, conceda o logon RDP só à conta de teste adicional.
$pastaPolitica = Join-Path $env:ProgramData 'CitizenTech\Politica'
New-Item -ItemType Directory -Path $pastaPolitica -Force | Out-Null
Get-GPOReport -Name $gpo -ReportType Html -Path (Join-Path $pastaPolitica 'politica.html')
$politica = Join-Path $pastaPolitica 'direitos.inf'
secedit.exe /export /cfg $politica /areas USER_RIGHTS /quiet
if ($LASTEXITCODE) { throw 'Falha ao consultar os direitos de logon.' }
$linha = (Select-String -LiteralPath $politica -Pattern '^SeRemoteInteractiveLogonRight\s*=').Line
if (!$linha) { throw 'Direito de logon RDP ausente na politica atual.' }
$sidTeste = '*' + (Get-ADUser 'ana.souza').SID.Value
if (($linha.Split('=')[1].Trim() -split ',\s*') -notcontains $sidTeste) {
    $ajuste = Join-Path $pastaPolitica 'rdp.inf'
    @('[Unicode]', 'Unicode=yes', '[Version]', 'signature="$CHICAGO$"', 'Revision=1',
      '[Privilege Rights]', "$linha,$sidTeste") | Set-Content -LiteralPath $ajuste -Encoding Unicode
    secedit.exe /configure /db "$pastaPolitica\rdp.sdb" /cfg $ajuste /areas USER_RIGHTS /quiet
    if ($LASTEXITCODE) { throw 'Falha ao conceder o logon RDP de demonstracao.' }
}
auditpol.exe /set /subcategory:"Logon" /success:enable /failure:enable
if ($LASTEXITCODE) { throw 'Falha na auditoria de logon.' }
auditpol.exe /set /subcategory:"File System" /success:enable /failure:enable
if ($LASTEXITCODE) { throw 'Falha na auditoria de arquivos.' }
$site = 'C:\inetpub\citizentech'
$acl = Get-Acl -Audit $site
$todos = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
$regra = New-Object System.Security.AccessControl.FileSystemAuditRule($todos,'ReadData,WriteData','ContainerInherit,ObjectInherit','None','Success,Failure')
$acl.SetAuditRule($regra)
Set-Acl -Path $site -AclObject $acl
Get-Content "$site\web.config" -TotalCount 1 | Out-Null
Get-ADGroupMember $grupo
Get-SmbShareAccess -Name CitizenTech
