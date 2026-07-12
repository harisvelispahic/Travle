# Build context is the Backend/ folder (see docker-compose.yml: context ./Backend).
# Multi-stage build on the .NET 10 (LTS) images.

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 5121
ENV ASPNETCORE_URLS=http://+:5121
ENV ASPNETCORE_ENVIRONMENT=Development

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore "Travle.WebAPI/Travle.WebAPI.csproj"

FROM build AS publish
RUN dotnet publish "Travle.WebAPI/Travle.WebAPI.csproj" -c Release -o /app --no-restore

FROM base AS final
WORKDIR /app
COPY --from=publish /app .

ENTRYPOINT ["dotnet", "Travle.WebAPI.dll"]
