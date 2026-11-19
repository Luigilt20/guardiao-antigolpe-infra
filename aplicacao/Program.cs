using Antigolpe.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRazorPages();
var app = builder.Build();
using (var db = new AppDbContext())
{
    db.Database.Migrate();
}
app.UseStaticFiles();
app.MapRazorPages();
app.Run();
