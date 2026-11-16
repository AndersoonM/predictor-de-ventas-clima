# Weather Sales Predictor 🛒☀️🌧️

Backend en **Spring Boot** para un proyecto de IA que predice qué productos de un supermercado se
venderán más o menos según el clima. La infraestructura cloud se simula localmente con
**[Floci](https://floci.io)** (emulador de AWS gratuito, MIT, sin cuenta ni credenciales reales).

Este repositorio cubre el entregable de la **fase 1**: inicializar Floci, configurar variables de
entorno, crear un proyecto Spring Boot básico y **conectarlo con la base de datos**.

> 📦 **Repositorio:** https://github.com/AndersoonM/predictor-de-ventas-clima
> 🔗 **Clonar:** `git clone https://github.com/AndersoonM/predictor-de-ventas-clima.git`

---

## 1. Análisis de la herramienta: servicios de Floci que se acoplan al proyecto

Floci emula 135 servicios de AWS en un único puerto (`4566`). Para este proyecto se priorizan estos:

| Servicio Floci | Para qué lo usaremos | Fase |
|---|---|---|
| **RDS (PostgreSQL)** | Base de datos relacional con productos, histórico de ventas y observaciones del clima. Floci levanta un contenedor **real** de PostgreSQL y lo expone por JDBC. | ✅ **Fase 1 (este repo)** |
| **S3** | Almacenar datasets históricos (CSV de ventas), datos de entrenamiento y artefactos del modelo. | Fase 2 |
| **Secrets Manager / SSM Parameter Store** | Guardar credenciales de BD y configuración fuera del código (equivalente a Key Vault / App Settings de Azure). | Fase 2 |
| **Lambda** | Función que consulta periódicamente una API de clima y guarda los datos en RDS. Corre en contenedores Docker reales. | Fase 2 |
| **EventBridge Scheduler** | Disparar la Lambda de ingesta de clima cada día/hora. | Fase 2 |
| **SQS** | Cola para procesar ventas/lecturas de clima de forma asíncrona. | Fase 2 |
| **Athena + Glue** | Consultas analíticas (SQL) sobre los CSV históricos en S3 para explorar la relación clima–ventas. Athena corre sobre DuckDB. | Fase 3 |
| **SageMaker / Bedrock** | Entrenamiento/serving del modelo y generación de explicaciones con IA. Floci los lista entre sus servicios; **antes de depender de ellos hay que revisar en su documentación qué operaciones emulan realmente.** | Fase 3 |
| **ElastiCache (Redis)** | Caché de predicciones ya calculadas. | Opcional |
| **CloudWatch** | Logs y métricas de la ingesta y del modelo. | Opcional |

**Por qué RDS primero:** el backend necesita una base de datos relacional desde el día uno, y Floci
usa el motor real (PostgreSQL), así que el código JDBC/JPA que escribamos funciona igual contra AWS RDS
en producción: solo cambiarían las variables de entorno.

### Arquitectura objetivo

```
 API de clima ──► Lambda (ingesta) ──┐        ┌────────────── Floci (AWS local) ─────────────┐
   (EventBridge Scheduler)           ├──────► │  RDS PostgreSQL   S3   SQS   Secrets Manager │
 CSV de ventas ──► S3 ───────────────┘        └───────────────▲──────────────────────────────┘
                                                              │ JDBC (fase 1)
                                              Spring Boot (REST) ──► Modelo de IA (predicción)
```

---

## 2. Requisitos

| Herramienta | Versión | Verificar | Instalar (Windows) |
|---|---|---|---|
| Docker (o Podman) | corriendo | `docker version` | Docker Desktop con WSL2 |
| JDK | 17+ | `java -version` | `winget install --id Microsoft.OpenJDK.21 -e` |
| Maven | 3.9+ | `mvn -v` | `winget install --id Apache.Maven -e` |
| AWS CLI | v2 | `aws --version` | `winget install --id Amazon.AWSCLI -e` |
| Git | cualquiera | `git --version` | `winget install --id Git.Git -e` |
| GitHub CLI *(solo para publicar)* | cualquiera | `gh --version` | `winget install --id GitHub.cli -e` |

> **Windows:** Docker Desktop con WSL2. Use PowerShell para los scripts `.ps1`, o Git Bash para los `.sh`.
>
> **JDK:** el proyecto compila con `--release 17`, así que funciona con JDK 17 a 25 (probado en 17 y 25).

---

## 3. Inicio rápido

```bash
# 1. Clonar
git clone https://github.com/AndersoonM/predictor-de-ventas-clima.git
cd predictor-de-ventas-clima

# 2. Levantar Floci + crear la base de datos RDS (PostgreSQL) y generar el .env
./scripts/setup-floci.sh                 # Linux / macOS / Git Bash
# .\scripts\setup-floci.ps1              # Windows PowerShell

# 3. Arrancar el backend
mvn spring-boot:run
```

Si PowerShell bloquea el script: `powershell -ExecutionPolicy Bypass -File .\scripts\setup-floci.ps1`.

### ¿Qué hace `setup-floci`?

1. Crea `.env` desde `.env.example` si no existe.
2. `docker compose up -d` → inicia Floci (puerto `4566` + rango RDS `7001-7069`).
3. Espera a que la API responda.
4. Crea la instancia **RDS PostgreSQL** `weather-sales-db` con `aws rds create-db-instance` (si no existía).
5. Espera el estado `available`, lee el puerto real y lo escribe en `.env`.
6. Comprueba que el puerto publicado acepta conexiones TCP.

> **Sobre el rango de puertos:** el compose publica `7001-7069` en vez del `7001-7099` por defecto de
> Floci porque en algunos equipos el `7070` ya está ocupado (por ejemplo, por AnyDesk) y Docker no
> puede hacer bind de un puerto ocupado. Si el `7070` está libre en el tuyo, puedes devolver el rango
> a `7001-7099` editando `docker-compose.yml` (el `ports:` y `FLOCI_SERVICES_RDS_PROXY_MAX_PORT`).

Equivalente manual con la CLI de Floci (opcional):

```bash
curl -fsSL https://floci.io/install.sh | sh
floci start && eval $(floci env)
```

---

## 4. Variables de entorno

Igual que las *App Settings / variables de entorno* en Azure App Service, **ninguna credencial queda
escrita en el código**: `application.yml` solo contiene placeholders `${VARIABLE}`.

| Variable | Valor por defecto (local) | Uso |
|---|---|---|
| `AWS_ENDPOINT_URL` | `http://localhost:4566` | Endpoint de Floci para AWS CLI / SDK |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `test` / `test` | Credenciales ficticias (Floci no valida cuentas reales) |
| `AWS_DEFAULT_REGION` | `us-east-1` | Región |
| `DB_INSTANCE_ID` | `weather-sales-db` | Identificador de la instancia RDS |
| `DB_HOST` | `localhost` | Host de la BD |
| `DB_PORT` | `7001` | Puerto del proxy RDS en Floci (rango `7001-7069`) |
| `DB_NAME` | `weathersales` | Nombre de la base de datos |
| `DB_USER` | `ws_admin` | Usuario maestro |
| `DB_PASSWORD` | `ws_pass_2026` | Contraseña (**obligatoria**, sin default en `application.yml`) |
| `SERVER_PORT` | `8080` | Puerto del backend |

**Orden de prioridad** (de mayor a menor): variables de entorno del sistema → archivo `.env` → valores por defecto de `application.yml`.

```bash
# Sobrescribir una variable sin tocar archivos (como en Azure)
DB_PORT=7002 mvn spring-boot:run                 # Linux/macOS
$env:DB_PORT="7002"; mvn spring-boot:run         # PowerShell
```

También funcionan los nombres estándar de Spring Boot, que tienen prioridad sobre `application.yml`
(`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`), útiles cuando
se despliegue en un entorno real.

El `.env` está en `.gitignore`; lo que se versiona es `.env.example`.

---

## 5. Verificación (evidencia del entregable)

Con el backend corriendo:

```bash
./scripts/verify.sh          # Linux / macOS / Git Bash
.\scripts\verify.ps1          # Windows PowerShell
```

o a mano:

```bash
curl http://localhost:8080/api/db/status
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/products
```

En PowerShell: `Invoke-RestMethod http://localhost:8080/api/db/status`

**Resultado esperado**

- En el log al arrancar:
  ```
  === CONEXION EXITOSA A LA BASE DE DATOS ===
  Motor   : PostgreSQL 16.x
  URL     : jdbc:postgresql://localhost:7001/weathersales?sslmode=disable
  Usuario : ws_admin
  Se cargaron 6 productos de ejemplo
  ```
- `/api/db/status` → `{"status":"UP","database":"weathersales","user":"ws_admin","version":"PostgreSQL 16...", ...}`
- `/actuator/health` → `"status":"UP"` con el detalle del componente `db`.
- `/api/products` → los 6 productos guardados en PostgreSQL.

### Generar la evidencia automáticamente

Un solo comando deja toda la evidencia del entregable en `docs/evidencias/` (logs reales, JSON
de la API, tablas de la base de datos y configuración con la contraseña enmascarada):

```powershell
.\scripts\collect-evidence.ps1                 # Windows
# ./scripts/collect-evidence.ps1               # Linux / macOS / Git Bash
```

Si el backend no está corriendo, el script lo levanta, espera a que responda y lo detiene al
terminar (usa `-KeepBackendRunning` para dejarlo arriba).

Los archivos generados y qué demuestra cada uno están en
[`docs/evidencias/README.md`](docs/evidencias/README.md).

Comandos útiles para las capturas:

```bash
docker ps
aws --endpoint-url http://localhost:4566 rds describe-db-instances \
  --query "DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Endpoint]"
```

---

## 6. Estructura del proyecto

```
.
├── docker-compose.yml          # Floci (AWS local) con RDS habilitado
├── .env.example                # Plantilla de variables de entorno
├── .gitattributes              # Normaliza finales de línea (LF en .sh)
├── pom.xml                     # Spring Boot 3.5 · Java 17
├── scripts/
│   ├── setup-floci.sh | .ps1   # Inicializa Floci + RDS + .env
│   ├── verify.sh | .ps1        # Prueba los endpoints
│   └── collect-evidence.ps1    # Genera la evidencia en docs/evidencias/
├── docs/evidencias/            # Evidencia del entregable (logs, JSON, tablas)
└── src/main/
    ├── resources/application.yml
    └── java/com/supermarket/weathersales/
        ├── domain/       Product, WeatherObservation, SaleRecord
        ├── repository/   Spring Data JPA
        ├── web/          ProductController, WeatherController, DbStatusController
        └── config/       DatabaseConnectionReporter, DataSeeder
```

Tablas creadas automáticamente (`ddl-auto: update`): `products`, `weather_observations`, `sales_records`.

---

## 7. Operación y solución de problemas

| Acción | Comando |
|---|---|
| Ver estado / logs de Floci | `docker compose ps` · `docker compose logs -f floci` |
| Detener (conserva datos) | `docker compose down` |
| Reiniciar desde cero | `docker compose down` → borrar carpeta `data/` y contenedores `floci-*` → `./scripts/setup-floci.sh` |
| Diagnóstico | `floci doctor` (si instaló floci-cli) |

| Problema | Causa probable / solución |
|---|---|
| `Could not resolve placeholder 'DB_PASSWORD'` | Falta el `.env`: ejecute `setup-floci` o copie `.env.example` a `.env`. |
| `Connection refused` en `localhost:7001` | La instancia no está `available` o el puerto cambió: ejecute de nuevo `setup-floci` (re-sincroniza `DB_PORT`). |
| `port is already allocated` al hacer `docker compose up` | Otro programa ocupa un puerto del rango RDS. Ajuste `ports:` y `FLOCI_SERVICES_RDS_PROXY_MAX_PORT` en `docker-compose.yml`. |
| La instancia RDS no arranca | Floci necesita el socket de Docker. Verifique que Docker corre y que el volumen `/var/run/docker.sock` está montado. |
| `ERROR: 'aws' no esta instalado o no esta en el PATH` | Instale AWS CLI v2: `winget install --id Amazon.AWSCLI -e`, y abra una terminal nueva. |
| Puerto 4566 u 8080 ocupado | Cambie `SERVER_PORT` en `.env` o libere el puerto. |
| Primera ejecución lenta | Docker descarga `floci/floci` y `postgres:16-alpine`. |

---

## 8. Subir el proyecto a GitHub

Con [GitHub CLI](https://cli.github.com/) instalado y autenticado (`gh auth login`), la forma más
rápida es:

```bash
gh repo create predictor-de-ventas-clima --public --source . --push
```

O de forma manual:

```bash
git init
git add .
git commit -m "feat: proyecto Spring Boot + Floci (RDS PostgreSQL)"
git branch -M main
git remote add origin https://github.com/AndersoonM/predictor-de-ventas-clima.git
git push -u origin main
```

Compruebe antes de hacer `push` que `.env` **no** aparece en `git status`:

```bash
git status --short
git check-ignore -v .env      # debe imprimir la regla de .gitignore
```

---

## 9. Próximos pasos

1. Bucket S3 para los CSV de ventas: `aws --endpoint-url http://localhost:4566 s3 mb s3://weather-sales-datasets`
2. Mover `DB_PASSWORD` a Secrets Manager.
3. Lambda + EventBridge Scheduler para ingerir el clima.
4. Endpoint `/api/predictions` que consuma el modelo de IA.
5. Migraciones con Flyway en lugar de `ddl-auto: update`.

## Referencias

- Floci: https://floci.io · Documentación: https://floci.io/floci/
- Servicio RDS en Floci: https://floci.io/floci/services/rds/
