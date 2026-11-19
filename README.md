# Guardião Antigolpe | Operating Systems

## Ficha da CitizenTech

O Guardião Antigolpe atende pessoas idosas que recebem mensagens suspeitas. O botão de ajuda da solução envia um pedido via MQTT. No painel, o operador registra a mensagem recebida, informa a classificação e o risco e acompanha a ocorrência pelo número de atendimento.

Para a disciplina de Operating Systems, adaptamos o console em C# do grupo para o navegador. A versão web conserva o modelo de ocorrências, o serviço de cadastro e consulta e as migrações do banco SQLite. O formulário permite cadastrar uma ocorrência, consultar por ID, alterar o status e excluir o registro. [Console de origem](https://github.com/alecolvet/Antigolpe-PainelDeProtecao/tree/00951b3189554c9638fbea1b6d456a84e3de3c9c) · [Código da aplicação web](aplicacao)

## Demonstração do painel

O vídeo legendado acompanha uma ocorrência fictícia desde o registro de uma tentativa de golpe por Pix até sua exclusão. A gravação mostra a aplicação executando localmente com ASP.NET Core e SQLite. [Assistir ou baixar a demonstração em MP4](evidencias/aplicacao/painel-de-ocorrencias.mp4) · [Resultado do teste HTTP](evidencias/aplicacao/teste-local.txt)

Para reproduzir o teste, execute o comando na raiz do repositório com o SDK .NET 10 e abra `http://127.0.0.1:5080/`. As migrações criam o banco no primeiro início.

```sh
dotnet run --project aplicacao/Guardiao.csproj --urls http://127.0.0.1:5080
```

## Ambiente de hospedagem

A VM `Guardiao-Antigolpe` usa VirtualBox, Windows Server 2022 Standard Evaluation com Desktop Experience, 2 vCPUs, 4 GB de RAM e disco virtual de 60 GiB no NVMe. A primeira instalação apresentou erros de NTFS. Na VM substituta, a configuração inicial do Administrator precede os testes abaixo.

| Componente | Configuração prevista nos scripts |
| --- | --- |
| Rede e identidade | Servidor `SRV-CITIZENTECH`, domínio `citizentech.local`, IPv4 `10.0.2.10/24`, gateway `10.0.2.2` e DNS `10.0.2.10` |
| Hospedagem com runtime (Caminho B) | IIS com ASP.NET Core 10 Hosting Bundle, site `CitizenTech` e pool `CitizenTechPool` |
| Acesso ao site | Na VM, `http://10.0.2.10/`. No host, `http://127.0.0.1:18081/` por encaminhamento NAT |
| Arquivos e permissões | Aplicação em `C:\inetpub\citizentech` com leitura e execução para o pool. Banco em `C:\ProgramData\GuardiaoAntigolpe\Dados` com permissão de modificação |
| Conta de teste do domínio | `CITIZENTECH\ana.souza`, integrante de `GG_CitizenTech_Admins`. A senha é definida dentro da VM |

O roteiro detalha a ordem de instalação do AD DS, DNS e IIS, a configuração da GPO, do compartilhamento e do acesso remoto, além dos comandos para capturar as evidências. [Roteiro de configuração](docs/roteiro-configuracao.md)

## Critérios e evidências

O teste HTTP e o vídeo acima verificam o fluxo da aplicação no host. A tabela indica o que falta demonstrar dentro do Windows Server.

| Critério | Pontos | Evidência a coletar na VM |
| --- | ---: | --- |
| Rede e identidade | 2 | IP fixo em `ipconfig /all`, resolução do hostname em `nslookup`, domínio e zona DNS |
| Aplicação no IIS | 2 | Site e pool iniciados, ACL da pasta e operação do painel no navegador |
| Monitoramento | 2 | Contadores de CPU, memória e disco ativos no PerfMon e evento de alerta |
| Recuperação automática | 1 | Parada controlada de W3SVC e do pool, indisponibilidade observada e retorno do painel com HTTP 200 |
| Logs e auditoria | 1 | Política de auditoria, evento de segurança e requisição registrada no log do IIS |
| Funcionamento completo | 2 | Saída da validação integrada e vídeo de até 7 minutos mostrando a infraestrutura, a falha e a aplicação no IIS |
