# syntax=docker/dockerfile:1

# ---- Build stage -----------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy csproj files first to leverage Docker layer caching for restore.
COPY ["SIGEA.Web/SIGEA.Web.csproj", "SIGEA.Web/"]
RUN dotnet restore "SIGEA.Web/SIGEA.Web.csproj"

# Copy the rest of the source and publish.
COPY ["SIGEA.Web/", "SIGEA.Web/"]
WORKDIR /src/SIGEA.Web
RUN dotnet publish "SIGEA.Web.csproj" -c Release -o /app/publish --no-restore

# ---- Runtime stage ----------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# Run as a non-root user.
RUN addgroup --gid 1000 appgroup \
    && adduser --uid 1000 --gid 1000 --disabled-password --gecos "" appuser

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true

EXPOSE 8080

USER appuser

ENTRYPOINT ["dotnet", "SIGEA.Web.dll"]
