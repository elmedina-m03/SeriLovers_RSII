using Microsoft.EntityFrameworkCore;
using SeriLovers.Worker;
using SeriLovers.Worker.Data;

var builder = Host.CreateApplicationBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection");

if (!string.IsNullOrWhiteSpace(connectionString))
{
    builder.Services.AddDbContext<WorkerDbContext>(options =>
        options.UseSqlServer(connectionString, sqlOptions => sqlOptions.CommandTimeout(60)));
}

builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
