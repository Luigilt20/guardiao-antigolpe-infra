# Alethos: guardião antigolpe | Operating Systems

## Integrantes da equipe

- Witalon Antonio Rodrigues — RM 559023
- Alexandre Colvet Delfino — RM 560059
- Enzo Luciano Barros de Oliveira — RM 559557
- Pedro Claudino Scarceli — RM 561023
- Luigi Thiengo Pires — RM 560755

## Ficha da CitizenTech

O Alethos atende pessoas idosas que recebem mensagens suspeitas. O botão de ajuda da solução envia um pedido via MQTT. No painel, o operador registra a mensagem recebida, informa a classificação e o risco e acompanha a ocorrência pelo número de atendimento.

Para a disciplina de Operating Systems, adaptamos o console em C# do grupo para o navegador. A versão web conserva o modelo de ocorrências, o serviço de cadastro e consulta e as migrações do banco SQLite. O formulário permite cadastrar uma ocorrência, consultar por ID, alterar o status e excluir o registro. [Console de origem](https://github.com/alecolvet/Antigolpe-PainelDeProtecao/tree/00951b3189554c9638fbea1b6d456a84e3de3c9c) · [Código da aplicação web](aplicacao)

[Ficha da CitizenTech](docs/ficha-citizentech.md)

## Demonstração do painel

O vídeo legendado mostra o domínio, o acesso remoto de uma usuária, a política aplicada, a pasta compartilhada, os testes do servidor e um atendimento fictício de golpe por Pix. O computador cliente acessa diretamente o IIS pela bridge privada do laboratório. [Demonstração do Windows Server e do painel (YouTube, 3min01s)](https://youtu.be/RAfcEyTncHM)

O painel também passou por um teste de cadastro, busca, atualização e exclusão no host. [Teste HTTP local](evidencias/aplicacao/teste-local.txt)

Para reproduzir o teste, execute o comando na raiz do repositório com o SDK .NET 10 e abra `http://127.0.0.1:5080/`. As migrações criam o banco no primeiro início.

```sh
dotnet run --project aplicacao/Guardiao.csproj --urls http://127.0.0.1:5080
```

## Ambiente de hospedagem

A VM `Guardiao-Antigolpe` usa VirtualBox, Windows Server 2022 Standard Evaluation com Desktop Experience, 2 vCPUs, 4 GB de RAM e disco virtual de 60 GiB no NVMe. O site e o pool estão em execução. Os testes abaixo foram realizados em 18/11/2026. A interface do VirtualBox usa a bridge privada `br-guardiao`. O host é o cliente de teste em `10.0.2.2`.

| Componente | Configuração do laboratório |
| --- | --- |
| Rede e identidade | Servidor `SRV-CITIZENTECH`, domínio `citizentech.local`, IPv4 `10.0.2.10/24`, gateway `10.0.2.2` e DNS `10.0.2.10` |
| Hospedagem com runtime (Caminho B) | IIS com ASP.NET Core 10 Hosting Bundle, site `CitizenTech` e pool `CitizenTechPool` |
| Acesso ao site | Na VM e no host, `http://10.0.2.10/`. Usando o DNS do laboratório, `http://srv-citizentech.citizentech.local/` |
| Arquivos e permissões | Aplicação em `C:\inetpub\citizentech` com leitura e execução para o pool. Banco em `C:\ProgramData\GuardiaoAntigolpe\Dados` com permissão de modificação |
| Conta de teste no domínio | `CITIZENTECH\ana.souza`, integrante de `GG_CitizenTech_Admins`. A senha é definida dentro da VM |

O roteiro detalha a ordem de instalação do AD DS, DNS e IIS, a configuração da GPO, do compartilhamento e do acesso remoto, além dos comandos para capturar as evidências. [Roteiro de configuração](docs/roteiro-configuracao.md)

## Critérios e evidências

| Critério | Pontos | Resultado e evidência |
| --- | ---: | --- |
| Rede e identidade | 2 | Hostname `SRV-CITIZENTECH`, DHCP desabilitado, IP fixo e DNS `10.0.2.10`. O DNS resolve o servidor, a porta 80 responde e o Active Directory contém o domínio, a usuária e o grupo. [AD e DNS](evidencias/dominio/dns-e-dominio.png) · [Usuária, grupo e GPO](evidencias/dominio/grupo-e-politica.png) · [Consulta pelo cliente](evidencias/dominio/acesso-do-cliente.txt). [ipconfig](evidencias/rede/ipconfig.png) · [Saída do PowerShell](evidencias/rede/rede.txt) |
| Aplicação no IIS | 2 | Site e pool iniciados, HTTP 200, acesso de leitura e execução no site e de modificação no banco. [Ocorrência no navegador](evidencias/iis/ocorrencia-no-navegador.png) · [Site e pool](evidencias/iis/site-e-pool.png) · [Permissões NTFS](evidencias/iis/permissoes.png) · [Get-Acl e vínculos do IIS](evidencias/iis/acesso-do-pool.png) · [Saída do servidor](evidencias/iis/web.txt) |
| Monitoramento | 2 | Coleta a cada 15 s. O evento 9001 registrou uso de CPU de 97%. O teste de memória também gerou um alerta ao elevar temporariamente o limite. [Monitor de Desempenho](evidencias/monitoramento/monitor-de-desempenho.png) · [PerfMon e tarefas](evidencias/monitoramento/limiares-e-agendamento.png) · [Contadores e eventos](evidencias/monitoramento/monitor.txt) |
| Recuperação automática | 1 | Após a parada do W3SVC, o teste observou a indisponibilidade e o HTTP 200 retornou após 57 s de espera. No teste separado do pool, a aplicação voltou a responder após 37 s. [Teste do serviço](evidencias/recuperacao/servico-restabelecido.png) · [Teste do pool](evidencias/recuperacao/teste-do-pool.png) · [Histórico da recuperação](evidencias/recuperacao/falhas.txt) |
| Logs e auditoria | 1 | Auditoria de logon e de arquivos habilitada para sucesso e falha. O evento 4663 registrou acesso a arquivos, e o log W3C do IIS registrou requisições GET com código 200. [Visualizador de Eventos](evidencias/auditoria/visualizador-de-eventos.png) · [Pasta de logs do IIS](evidencias/auditoria/pasta-dos-logs.png) · [Tela do servidor](evidencias/auditoria/eventos-e-iis.png) · [Saída de auditoria e HTTP](evidencias/auditoria/auditoria.txt) |
| Funcionamento completo | 2 | Cadastro, busca, atualização e exclusão executados pelo navegador no IIS. Ana entrou por [RDP](evidencias/dominio/sessao-rdp.png), recebeu a GPO e teve o [Painel de Controle bloqueado](evidencias/dominio/painel-de-controle-bloqueado.png). O cliente leu o arquivo de atendimento pelo [compartilhamento SMB](evidencias/dominio/compartilhamento-no-cliente.png). [Resumo da validação](evidencias/dominio/validacao-integrada.png) · [Captura integral do bloco da seção 8.1](evidencias/dominio/bloco-de-validacao.png) · [Saída completa do Windows](evidencias/dominio/verificacao-da-infraestrutura.txt). [Vídeo legendado](https://youtu.be/RAfcEyTncHM) |

## DFS opcional

A raiz de domínio `\\citizentech.local\CitizenTechDFS` está online como Domain V2. A pasta `Atendimento` aponta para o compartilhamento `\\SRV-CITIZENTECH\CitizenTech`. O PowerShell confirmou o acesso a `atendimento.txt` pelo caminho DFS. [Captura do PowerShell](evidencias/dfs/raiz-dfs.png) · [Saída dos comandos](evidencias/dfs/validacao-dfs.txt).
