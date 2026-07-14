# Build context is the Backend/ folder (see docker-compose.yml: context ./Backend).
# Worker runs on the runtime image (no HTTP surface), not aspnet.

FROM mcr.microsoft.com/dotnet/runtime:10.0 AS base
WORKDIR /app
ENV DOTNET_ENVIRONMENT=Development

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore "Travle.Worker/Travle.Worker.csproj"

FROM build AS publish
RUN dotnet publish "Travle.Worker/Travle.Worker.csproj" -c Release -o /app --no-restore

FROM base AS final
WORKDIR /app
COPY --from=publish /app .

ENTRYPOINT ["dotnet", "Travle.Worker.dll"]
