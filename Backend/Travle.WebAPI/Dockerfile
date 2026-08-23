# Build context is the Backend/ folder (see docker-compose.yml: context ./Backend).
# Multi-stage build on the .NET 10 (LTS) images.

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 5121
ENV ASPNETCORE_URLS=http://+:5121
# ASPNETCORE_ENVIRONMENT is NOT baked in: docker-compose supplies it from .env (course §3.3 —
# configuration lives in one place, never hardcoded).

# QuestPDF renders the report PDFs via SkiaSharp, which needs fontconfig present on Linux. The library
# bundles its own fonts, so no font packages are required — only the native dependency.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

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
