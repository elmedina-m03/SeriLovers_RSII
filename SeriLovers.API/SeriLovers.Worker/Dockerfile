FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY SeriLovers.Worker/SeriLovers.Worker.csproj ./SeriLovers.Worker/
RUN dotnet restore ./SeriLovers.Worker/SeriLovers.Worker.csproj

COPY SeriLovers.Worker/ ./SeriLovers.Worker/
RUN dotnet publish ./SeriLovers.Worker/SeriLovers.Worker.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish ./

ENTRYPOINT ["dotnet", "SeriLovers.Worker.dll"]

