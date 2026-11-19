#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory,GroupPolicy
$ErrorActionPreference = 'Stop'
$dominio = Get-ADDomain
if ($dominio.DNSRoot -ne 'citizentech.local') { throw 'Dominio inesperado.' }
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
