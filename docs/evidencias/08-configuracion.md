# Evidencia 7 - Configuracion del entorno
# Generado: 2026-11-16 15:23:08

## Versiones

```
Java  : java version "25.0.4.1" 2026-08-18 LTS
Maven : Apache Maven 3.10.0 (c43a36b8d67be7e0805a411bc0898af1a51f5472)
Docker: Docker version 29.8.0, build 88096ef
AWS   : aws-cli/2.40.2 Python/3.14.8 Windows/11 exe/AMD64
```

## Variables de entorno efectivas (contrasena enmascarada)

| Variable | Valor |
|---|---|
| AWS_ENDPOINT_URL | http://localhost:4566 |
| AWS_DEFAULT_REGION | us-east-1 |
| DB_INSTANCE_ID | weather-sales-db |
| DB_HOST | localhost |
| DB_PORT | 7001 |
| DB_NAME | weathersales |
| DB_USER | ws_admin |
| DB_PASSWORD | ws******** |
| SERVER_PORT | 8080 |

> La contrasena real vive solo en el archivo .env, que esta en .gitignore y nunca se versiona.

## URL JDBC efectiva

```
jdbc:postgresql://localhost:7001/weathersales?sslmode=disable
```
