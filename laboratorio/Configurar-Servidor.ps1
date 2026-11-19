#Requires -Version 5.1
#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory)]
    [ValidateSet('Preparar', 'Promover')]
    [string]$Etapa,
    [Parameter(Mandatory)]
    [ipaddress]$IpServidor,
    [Parameter(Mandatory)]
    [ipaddress]$IpGateway,
    [ValidateRange(1, 30)]
    [int]$Prefixo = 24
)

$ErrorActionPreference = 'Stop'
$nome = 'SRV-CITIZENTECH'
$dominio = 'citizentech.local'
$endereco = $IpServidor.IPAddressToString
$gateway = $IpGateway.IPAddressToString

# A interface deve estar conectada a rede do laboratorio antes da configuracao.
$placas = @(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway.NextHop -contains $gateway })
if ($placas.Count -ne 1) { throw "Esperada uma interface com gateway $gateway." }
$indice = $placas[0].InterfaceIndex

if ($Etapa -eq 'Preparar') {
    $funcoes = Install-WindowsFeature AD-Domain-Services,DNS,FS-FileServer,GPMC,Web-Server,Web-Scripting-Tools -IncludeManagementTools
    if (-not $funcoes.Success) { throw "Instalacao de funcoes: $($funcoes.ExitCode)" }
    $ipv4 = Get-NetIPAddress -InterfaceIndex $indice -AddressFamily IPv4
    if ($ipv4.IPAddress -notcontains $endereco) {
        if (@($ipv4 | Where-Object PrefixOrigin -eq 'Manual').Count) {
            throw 'Ja existe um endereco manual. Confira a rede antes de prosseguir.'
        }
        # O cmdlet desativa DHCP ao atribuir um endereco fixo.
        New-NetIPAddress -InterfaceIndex $indice -IPAddress $endereco -PrefixLength $Prefixo
        if (-not (Get-NetRoute -InterfaceIndex $indice -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Where-Object NextHop -eq $gateway)) {
            New-NetRoute -InterfaceIndex $indice -DestinationPrefix '0.0.0.0/0' -NextHop $gateway
        }
    }
    Set-DnsClientServerAddress -InterfaceIndex $indice -ServerAddresses $endereco
    if ($env:COMPUTERNAME -ne $nome) {
        Rename-Computer -NewName $nome -Restart
    } elseif ($funcoes.RestartNeeded -eq 'Yes') {
        Restart-Computer
    }
    return
}

if ($env:COMPUTERNAME -ne $nome) { throw "Esperado $nome depois do reinicio." }
if (-not (Get-NetIPAddress -InterfaceIndex $indice -IPAddress $endereco -PrefixOrigin Manual -ErrorAction SilentlyContinue)) {
    throw 'Confira o IP fixo antes de promover o servidor.'
}
if ((Get-DnsClientServerAddress -InterfaceIndex $indice -AddressFamily IPv4).ServerAddresses -notcontains $endereco) {
    throw 'Confira o DNS da interface.'
}
$computador = Get-CimInstance Win32_ComputerSystem
if ($computador.PartOfDomain) {
    if ($computador.Domain -eq $dominio -and $computador.DomainRole -ge 4) {
        Get-ADDomain | Select-Object DNSRoot, NetBIOSName
        return
    }
    throw "A VM ja pertence a $($computador.Domain)."
}
# O proprio assistente pede a senha DSRM localmente e reinicia apos a promocao.
Install-ADDSForest -DomainName $dominio -DomainNetbiosName CITIZENTECH -InstallDns
