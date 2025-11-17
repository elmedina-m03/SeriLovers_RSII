# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY SeriLovers.API.csproj ./
RUN dotnet restore SeriLovers.API.csproj

COPY . ./
RUN dotnet publish SeriLovers.API.csproj -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:5149
EXPOSE 5149

COPY --from=build /app/publish ./

ENTRYPOINT ["dotnet", "SeriLovers.API.dll"]
