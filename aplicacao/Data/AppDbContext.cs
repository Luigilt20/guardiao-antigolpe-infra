using Antigolpe.Models;
using Microsoft.EntityFrameworkCore;
using System.IO;

namespace Antigolpe.Data
{
    public class AppDbContext : DbContext
    {
        public DbSet<Ocorrencia> Ocorrencias { get; set; }

        protected override void OnConfiguring(
            DbContextOptionsBuilder optionsBuilder)
        {
            var pasta = Environment.GetEnvironmentVariable("GUARDIAO_DADOS")
                ?? Path.Combine(AppContext.BaseDirectory, "Dados");
            Directory.CreateDirectory(pasta);
            var conexao = new Microsoft.Data.Sqlite.SqliteConnectionStringBuilder
            {
                DataSource = Path.Combine(pasta, "antigolpe.db")
            };
            optionsBuilder.UseSqlite(conexao.ToString());
        }
    }
}
