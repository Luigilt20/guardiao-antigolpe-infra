using Antigolpe.Models;
using Antigolpe.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Antigolpe.Pages;

public class IndexModel : PageModel
{
    private readonly OcorrenciaService service = new();
    public static readonly string[] Classificacoes = ["Golpe", "Suspeito", "Seguro"];
    public static readonly string[] Riscos = ["Alto", "Médio", "Baixo"];
    public static readonly string[] Status = ["Pendente", "Em análise", "Resolvida"];

    [BindProperty] public string Mensagem { get; set; } = "";
    [BindProperty] public string Classificacao { get; set; } = "";
    [BindProperty] public string Risco { get; set; } = "";
    [BindProperty] public string? Motivo { get; set; }
    [TempData] public string? Aviso { get; set; }
    public List<Ocorrencia> Ocorrencias { get; private set; } = [];

    public void OnGet(string? busca)
    {
        if (string.IsNullOrWhiteSpace(busca))
            Ocorrencias = service.ListarTodas();
        else if (int.TryParse(busca, out var id) && service.BuscarPorId(id) is { } registro)
            Ocorrencias.Add(registro);
    }

    public IActionResult OnPostCadastrar()
    {
        if (string.IsNullOrWhiteSpace(Mensagem) || !Classificacoes.Contains(Classificacao) || !Riscos.Contains(Risco))
        {
            Aviso = "Informe a mensagem, a classificação e o nível de risco.";
            Ocorrencias = service.ListarTodas();
            return Page();
        }
        var registro = new Ocorrencia {
            Mensagem = Mensagem.Trim(), ClassificacaoIA = Classificacao,
            NivelRisco = Risco, MotivoAnalise = Motivo?.Trim() ?? ""
        };
        service.Cadastrar(registro);
        Aviso = $"Ocorrência #{registro.Id} cadastrada.";
        return RedirectToPage();
    }

    public IActionResult OnPostAtualizar(int id, string novoStatus)
    {
        if (!Status.Contains(novoStatus))
            Aviso = "Selecione um status válido.";
        else
            Aviso = service.AtualizarStatus(id, novoStatus) ? $"Status da ocorrência #{id} atualizado." : "Ocorrência não encontrada.";
        return RedirectToPage();
    }

    public IActionResult OnPostExcluir(int id)
    {
        Aviso = service.Excluir(id) ? $"Ocorrência #{id} excluída." : "Ocorrência não encontrada.";
        return RedirectToPage();
    }
}
