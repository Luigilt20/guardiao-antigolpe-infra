# Ficha da CitizenTech

O Guardião Antigolpe ajuda pessoas idosas a pedir orientação quando recebem mensagens suspeitas. No painel, o operador registra a mensagem, informa a classificação, o nível de risco e o motivo, e acompanha o atendimento pelo número da ocorrência. A demonstração usa um pedido fictício de Pix antecipado.

| Item | Configuração |
| --- | --- |
| Aplicação | Painel em C# e ASP.NET Core com Razor Pages, Entity Framework Core e SQLite. Adaptado do console da equipe. |
| Hospedagem | Caminho B do roteiro. Windows Server 2022 com IIS, ASP.NET Core Hosting Bundle, site `CitizenTech` e pool `CitizenTechPool`. |
| Servidor | `SRV-CITIZENTECH`, IPv4 fixo `10.0.2.10/24`. |
| Domínio do laboratório | `citizentech.local` |
| Conta utilizada nos testes de usuário | `CITIZENTECH\ana.souza` |
| Critérios e resultados dos testes | [Tabela de evidências no README](../README.md#critérios-e-evidências) |

## Integrantes da equipe

- Witalon — RM 559023
- Alexandre Colvet — RM 560059
- Enzo Luciano — RM 559557
- Pedro Scarceli — RM 561023
- Luigi Thiengo — RM 560755
