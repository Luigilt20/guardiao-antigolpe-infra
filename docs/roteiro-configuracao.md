# Roteiro de configuração da infraestrutura do Guardião Antigolpe

## Ambiente

1. Usar Windows Server 2019 ou 2022 com Desktop Experience em uma VM de 2 vCPUs, pelo menos 4 GB de RAM e disco virtual de 60 GB. No computador de Luigi, manter a VM e o VDI ativo no NVMe. A ISO de instalação fica arquivada no disco `discoooolol`. Na VM, abrir o Windows PowerShell 5.1 como administrador.
   No host Linux, execute `bash laboratorio/preparar-vm.sh` a partir da pasta do projeto com o VirtualBox instalado. Inicie a VM Guardiao-Antigolpe e selecione **Windows Server 2022 Standard Evaluation (Desktop Experience)** no instalador. O adaptador 1 usa o modo **Bridged Adapter** com a interface privada `br-guardiao`. Na VM, use IPv4 `10.0.2.10/24`, gateway `10.0.2.2` e DNS `10.0.2.10`. No host, a bridge tem IP `10.0.2.2/24`. Para voltar a ativar essa rede depois de reiniciar o host Linux, execute `nmcli connection up guardiao-laboratorio` e `nmcli connection up guardiao-link`. Em outro computador, selecione a interface da rede do laboratório e ajuste os endereços. Para usar o script de criação com outra bridge, informe o nome em `BRIDGE_LAB`.
2. Renomear para `SRV-CITIZENTECH`, reiniciar e configurar o IP fixo com o índice da interface, máscara e gateway reais da rede de laboratório. Anotar esses valores.
3. Instalar AD DS e DNS, promover a VM a controlador do domínio `citizentech.local` e configurar o DNS do servidor. Validar com `Get-ADDomain`, `Get-DnsServerZone` e `nslookup srv-citizentech.citizentech.local`.
4. Criar a OU `CitizenTech`, o grupo `GG_CitizenTech_Admins` e uma conta de demonstração. Aplicar a GPO à OU, preparar o compartilhamento SMB e testar o acesso remoto a partir de um cliente do laboratório. Validar o acesso efetivo no cliente com a conta apropriada.
5. Instalar IIS e preparar site `CitizenTech`, pool `CitizenTechPool` e pasta `C:\inetpub\citizentech`. Usar um binding próprio, por exemplo `srv-citizentech.citizentech.local` na porta 80, e confirmar o acesso com `Test-NetConnection`. Conceder leitura e execução à identidade do pool na pasta publicada. Se a aplicação precisar de escrita, concedê-la somente no diretório de dados correspondente.
6. Habilitar auditoria de logon e acesso a arquivos conforme o roteiro da FIAP. Configurar a auditoria da pasta com uma SACL, gerar um acesso de teste e confirmar o evento no log Security. Conferir também o log HTTP do site no IIS.

## Publicação

O painel usa ASP.NET Core 10, EF Core e SQLite. Na pasta do repositório, use o SDK .NET 10 para gerar a pasta de publicação. O comando inclui a aplicação, o módulo nativo do SQLite para Windows e o `web.config` usado pelo IIS.

```sh
dotnet publish aplicacao/Guardiao.csproj -c Release -p:UseAppHost=false -o site
```

Na mídia de apoio, coloque a pasta `site`, os arquivos de `laboratorio`, a pasta `scripts` e o .NET Hosting Bundle 10.0.15 com o nome `hosting.exe`. Na VM, após instalar o IIS e configurar o IP 10.0.2.10, execute `.\Publicar-Painel.ps1` no PowerShell administrativo a partir dessa mídia. O script confere o SHA-512 publicado pela Microsoft, instala o módulo ASP.NET Core, cria o pool dedicado e concede ao processo acesso de gravação no diretório do SQLite. O site responde em `http://10.0.2.10/` pela bridge. O vínculo HTTP com o nome `srv-citizentech.citizentech.local` direciona as requisições pelo nome ao site CitizenTech tanto em IPv4 como em IPv6. [Hosting Bundle oficial](https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/10.0.15/dotnet-hosting-10.0.15-win.exe) · [Hospedagem com IIS](https://learn.microsoft.com/aspnet/core/host-and-deploy/iis/).

Para testar fora da VM, execute `dotnet run --project aplicacao/Guardiao.csproj --urls http://127.0.0.1:5080` e abra esse endereço. O primeiro acesso usa um banco vazio. Cadastre uma ocorrência fictícia, busque o ID exibido, altere o status e confira a alteração antes de excluir o registro.

Depois de publicar o site e promover o domínio, execute `.\Configurar-Dominio.ps1` no PowerShell elevado da VM. O script cria a OU, a conta de demonstração, o grupo, a GPO e o compartilhamento. Para o laboratório isolado, habilita o RDP, mantém os direitos de logon existentes e acrescenta a conta de demonstração ao direito de logon pela Área de Trabalho Remota. A GPO da OU aplica NoControlPanel à sessão da usuária. O script também configura a zona reversa do laboratório e a auditoria. Defina a senha de demonstração diretamente na VM quando solicitado.

## Monitoramento e recuperação

Na mídia de apoio, execute `.\Ativar-Monitoramento.ps1` para instalar os scripts e registrar as duas tarefas descritas abaixo. Para coletar as saídas da verificação depois dos testes, execute `.\Validar-Infraestrutura.ps1`. O arquivo de texto fica em `C:\ProgramData\CitizenTech\Evidencias`.

Copie os quatro scripts para `C:\Program Files\CitizenTech\Scripts`. Mantenha a pasta de execução gravável somente por administradores e pelo sistema, pois as tarefas rodam como `SYSTEM`. O script também agenda o início dos conjuntos do PerfMon um minuto após o boot da VM. Aponte `$url` para uma rota que devolva HTTP 200 diretamente e preencha `$texto` com um trecho ASCII do HTML ou JSON que identifique a aplicação no corpo da resposta.

```powershell
$scripts = 'C:\Program Files\CitizenTech\Scripts'
$url = Read-Host 'URL da CitizenTech no IIS'
$texto = Read-Host 'Trecho do HTML ou JSON que identifica a aplicacao'

if (-not [System.Diagnostics.EventLog]::SourceExists('CitizenTechMonitor')) {
    New-EventLog -LogName Application -Source 'CitizenTechMonitor'
}

& "$scripts\Monitor-Recursos.ps1"
& "$scripts\Monitor-Recursos.ps1" -LimiteMemoriaMB 2147483647
Get-WinEvent -FilterHashtable @{ LogName='Application'; ProviderName='CitizenTechMonitor'; Id=9001 } -MaxEvents 1
& "$scripts\Recupera-Site.ps1" -Url $url -TextoEsperado $texto
```

A segunda medição força um alerta com um limiar de demonstração. Registre esse limiar junto da evidência. Execute `& "$scripts\Configurar-PerfMon.ps1"` em PowerShell elevado. Ele cria e inicia os conjuntos `CitizenTech_Monitor` (histórico circular de até 64 MB) e `CitizenTech_Limiares` (evento quando a CPU ultrapassa 80%, a memória disponível cai abaixo de 500 MB ou restam menos de 15 GiB em disco). Use os nomes de contadores da língua instalada e capture o conjunto ativo com os três contadores. O script escreve seu alerta também no log Application.

Agende monitoramento a cada cinco minutos e recuperação a cada minuto. O exemplo abaixo pressupõe uma URL e um marcador simples, sem aspas duplas ou barras invertidas. Execute na VM dedicada.

```powershell
$exe = "$PSHOME\powershell.exe"
$inicio = (Get-Date).AddMinutes(1)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$opcoes = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew

$monitor = New-ScheduledTaskAction -Execute $exe -Argument ('-NoProfile -NonInteractive -File "{0}\Monitor-Recursos.ps1"' -f $scripts)
$aCadaCinco = New-ScheduledTaskTrigger -Once -At $inicio -RepetitionInterval (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'CitizenTech_Monitor_Alertas' -Action $monitor -Trigger $aCadaCinco -Principal $principal -Settings $opcoes

$argsRecuperacao = '-NoProfile -NonInteractive -File "{0}\Recupera-Site.ps1" -Url "{1}" -TextoEsperado "{2}"' -f $scripts, $url, $texto
$recuperacao = New-ScheduledTaskAction -Execute $exe -Argument $argsRecuperacao
$aCadaMinuto = New-ScheduledTaskTrigger -Once -At $inicio -RepetitionInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'CitizenTech_Recuperacao' -Action $recuperacao -Trigger $aCadaMinuto -Principal $principal -Settings $opcoes

sc.exe failure W3SVC reset= 86400 actions= restart/5000/restart/10000/restart/30000
sc.exe qfailure W3SVC
Get-ScheduledTask -TaskName 'CitizenTech_*' | Select-Object TaskName, State
```

Confira o histórico da tarefa e uma linha `OK HTTP 200` em `logs\recuperacao.log`. Execute cada parada logo após uma rodada da tarefa para deixar tempo de observar a indisponibilidade.

```powershell
& "$scripts\Teste-Falha.ps1" -Url $url -TextoEsperado $texto -Alvo Servico -SimularFalha
& "$scripts\Teste-Falha.ps1" -Url $url -TextoEsperado $texto -Alvo Pool -SimularFalha
Get-Content "$scripts\logs\recuperacao.log" -Tail 12
```

Durante a parada, o Windows pode informar `Stopping` antes de chegar a `Stopped`. O teste verifica a indisponibilidade por HTTP e depois exige tanto o estado operacional quanto o conteúdo correto da aplicação. Nesta VM, a espera até o HTTP 200 foi de 57 s após a indisponibilidade observada do serviço e de 37 s no teste separado do pool. A configuração consultada por `sc.exe qfailure` cobre falhas do serviço. A parada controlada do teste é recuperada pela tarefa. Capture o terminal e o log com os horários correspondentes. [Gatilhos no Agendador de Tarefas](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasktrigger).

## Evidências e vídeo

No PowerShell elevado, confira a auditoria de logon e o caminho dos logs específicos do site após fazer uma requisição ao Guardião Antigolpe.

```powershell
auditpol /get /subcategory:"Logon"
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 3 |
    Select-Object TimeCreated,Id,@{Name='Usuario';Expression={$_.Properties[5].Value}}
$siteIIS = Get-Website -Name 'CitizenTech'
$raizLogs = [Environment]::ExpandEnvironmentVariables($siteIIS.logFile.directory)
$ultimo = Get-ChildItem (Join-Path $raizLogs "W3SVC$($siteIIS.Id)") -Filter '*.log' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($ultimo) { Get-Content $ultimo.FullName -Tail 8 }
```

Capture rede e AD/DNS, site e pool do IIS, acesso no navegador, permissões NTFS, GPO e compartilhamento, PerfMon e alerta, parada e recuperação, log Security e log HTTP. Termine com o bloco de validação final da seção 8.1 do roteiro da FIAP. Insira os links das capturas na tabela do README e use dados fictícios na demonstração.

| Tempo | Demonstração |
| --- | --- |
| 0:00–1:30 | Nome, IP, DNS, domínio, usuário e grupo |
| 1:30–3:30 | Site no IIS, pool, ACL, GPO e compartilhamento |
| 3:30–4:30 | PerfMon e alerta |
| 4:30–5:40 | Parada controlada e recuperação pela tarefa |
| 5:40–7:00 | Auditoria, log HTTP e aplicação funcionando |
