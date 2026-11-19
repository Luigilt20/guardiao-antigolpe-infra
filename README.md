# Guardião Antigolpe | Operating Systems

## Ficha da CitizenTech

**Guardião Antigolpe** atende pessoas idosas que recebem mensagens suspeitas e precisam de ajuda antes de tomar decisões, como transferir dinheiro.

O botão de ajuda publica um pedido via MQTT. O painel em C# permite cadastrar e acompanhar ocorrências. Para Operating Systems, o grupo adaptou o menu do console para uma página web que usa o mesmo modelo de ocorrências, serviço e migrações do SQLite. [Repositório do painel](https://github.com/alecolvet/Antigolpe-PainelDeProtecao)

## Aplicação e ambiente

| Item | Estado |
| --- | --- |
| Código recebido | [Antigolpe-PainelDeProtecao](https://github.com/alecolvet/Antigolpe-PainelDeProtecao), C# com .NET 10, EF Core e SQLite |
| Interface do código recebido | Menu de terminal para cadastrar, consultar, atualizar e excluir ocorrências. O ponto de entrada usa `Console.ReadLine()` e não abre um servidor HTTP. |
| Hospedagem com runtime (Caminho B) | [Guardião Antigolpe em ASP.NET Core Razor Pages](aplicacao), adaptado do [commit do console](https://github.com/alecolvet/Antigolpe-PainelDeProtecao/tree/00951b3189554c9638fbea1b6d456a84e3de3c9c). Cadastro, lista, busca por ID, alteração de status e exclusão verificados em [teste HTTP local](evidencias/aplicacao/teste-local.txt). A classificação é informada pelo operador. |
| Windows Server | VM Guardiao-Antigolpe, VirtualBox, Windows Server 2022 Standard Evaluation com Desktop Experience, 2 vCPUs, 4 GB de RAM e VDI de 60 GiB no NVMe. A primeira instalação entrou em recuperação após erros de NTFS. Validação da infraestrutura na VM substituta pendente. |
| Nome e domínio previstos | `SRV-CITIZENTECH` e `citizentech.local` |
| Endereço IP, URL do site e conta de demonstração | Planejados para o laboratório: `10.0.2.10/24`, `http://10.0.2.10/`, `CITIZENTECH\ana.souza` |
| Caminho de publicação | Prescrito no [script de publicação](laboratorio/Publicar-Painel.ps1): `C:\inetpub\citizentech`, banco em `C:\ProgramData\GuardiaoAntigolpe\Dados` |

## Rastreabilidade

| Critério | Pontos | Evidência a anexar |
| --- | ---: | --- |
| Rede e identidade | 2 | `ipconfig /all`, `nslookup`, `Get-ADDomain` e `Get-DnsServerZone` |
| Aplicação no IIS | 2 | `Get-Website`, `Get-WebAppPoolState`, `Get-Acl` e Guardião Antigolpe aberto no navegador |
| Monitoramento | 2 | Monitor de Desempenho com CPU, memória e disco e execução do script de alerta |
| Recuperação | 1 | `sc.exe qfailure W3SVC`, parada controlada, retorno do HTTP 200 e log da tarefa |
| Logs e auditoria | 1 | Saída de `auditpol`, evento no log Security e logs das requisições do IIS |
| Funcionamento | 2 | Validação final pelo PowerShell e vídeo de até 7 minutos |

O [roteiro de configuração](docs/roteiro-configuracao.md) contém a sequência de execução e os comandos dos scripts. A validação no Windows Server e a captura das evidências ainda estão pendentes. Enviar o link do repositório no Teams por um integrante até **19/11 às 23h55**.
