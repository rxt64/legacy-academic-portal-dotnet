using Microsoft.EntityFrameworkCore;
using SIGEA.Web.DAL;
using SIGEA.Web.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

// The schema is owned by db/schema/01_schema.sql; EF Core must never create,
// migrate, or drop the database (see AddDbContext below: no EnsureCreated()/
// Migrate() call is ever made).
var connectionString = SchoolContext.ResolveConnectionString(builder.Configuration, "SchoolContext");
builder.Services.AddDbContext<SchoolContext>(options => options.UseSqlServer(connectionString));

builder.Services.AddSingleton<LabGate>();
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

builder.Services.AddControllersWithViews();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
}

app.UseStaticFiles();
app.UseRouting();
app.UseSession();
app.UseAuthorization();

// Normal screens. The Lab controller is reachable by the default route as
// well, but every lab action carries [LabOnly], which returns 404 unless the
// labs are enabled AND the caller is on loopback. See
// Infrastructure/LabGate + LabOnlyAttribute.
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
