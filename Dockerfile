FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ["src/SIGEA.Web/SIGEA.Web.csproj", "src/SIGEA.Web/"]
RUN dotnet restore "src/SIGEA.Web/SIGEA.Web.csproj"
COPY ["src/SIGEA.Web/", "src/SIGEA.Web/"]
WORKDIR /src/src/SIGEA.Web
RUN dotnet publish "SIGEA.Web.csproj" -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "SIGEA.Web.dll"]
