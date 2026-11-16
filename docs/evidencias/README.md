# Evidencias del entregable

Esta carpeta contiene la **evidencia real y reproducible** de la fase 1: inicialización de
Floci, configuración del proyecto Spring Boot y conexión del backend con la base de datos.

Todo lo que hay aquí se genera con un solo comando:

```powershell
# Windows PowerShell
.\scripts\collect-evidence.ps1

# Linux / macOS / Git Bash
./scripts/collect-evidence.ps1   # o equivalente en bash
```

El script deja el backend arriba si no lo estaba, ejecuta las consultas, guarda los archivos
y lo detiene. Si prefieres que el backend siga corriendo al terminar: `-KeepBackendRunning`.

---

## 1. Archivos generados

| Archivo | Qué demuestra | Origen |
|---|---|---|
| `01-floci-contenedores.txt` | **Floci inicializado**: el contenedor `floci` corriendo y sus puertos publicados | `docker ps` + `docker compose ps` |
| `02-rds-instancia.json` | **La instancia RDS existe** con estado `available` y su endpoint/puerto | `aws rds describe-db-instances` |
| `03-springboot-arranque.log` | **El backend arrancó y se conectó**: bloque `CONEXION EXITOSA A LA BASE DE DATOS` con motor, URL JDBC y usuario | log de `mvn spring-boot:run` |
| `04-db-status.json` | **Consulta real a la base de datos** desde el backend (`current_database()`, `current_user`, `version()`) | `GET /api/db/status` |
| `05-actuator-health.json` | **El health check reporta `UP`** con el detalle del componente `db` | `GET /actuator/health` |
| `06-productos.json` | **Escritura y lectura funcionan**: los productos sembrados salen de PostgreSQL | `GET /api/products` |
| `07-tablas-bd.txt` | **El esquema se creó en la BD real** (`products`, `weather_observations`, `sales_records`) | `psql \dt` dentro del contenedor de PostgreSQL |
| `08-configuracion.md` | Versiones y variables de entorno, **con la contraseña enmascarada** | entorno local |
| `logs/springboot-arranque-completo.log` | Log completo de arranque, sin filtrar | `mvn spring-boot:run` |

## 2. Resultado esperado

En `03-springboot-arranque.log` debe aparecer:

```
=== CONEXION EXITOSA A LA BASE DE DATOS ===
Motor   : PostgreSQL 16.x
URL     : jdbc:postgresql://localhost:7001/weathersales?sslmode=disable
Usuario : ws_admin
Se cargaron 6 productos de ejemplo
```

Y en `04-db-status.json`:

```json
{
  "status": "UP",
  "database": "weathersales",
  "user": "ws_admin",
  "version": "PostgreSQL 16.x ..."
}
```

## 3. Capturas de pantalla (opcionales)

Los archivos de arriba son la evidencia verificable y automática. Si además quieres_adjuntar
capturas al informe, estas son las que corresponden:

| Archivo | Qué debe mostrar | Dónde obtenerlo |
|---|---|---|
| `01-floci-iniciado.png` | Floci corriendo | `docker ps` o Docker Desktop |
| `02-rds-available.png` | Instancia RDS en estado `available` con su endpoint | `aws --endpoint-url http://localhost:4566 rds describe-db-instances --query "DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Endpoint]"` |
| `03-springboot-log-conexion.png` | Log `CONEXION EXITOSA A LA BASE DE DATOS` | salida de `mvn spring-boot:run` |
| `04-db-status.png` | JSON con `"status":"UP"` | `Invoke-RestMethod http://localhost:8080/api/db/status` |
| `05-productos.png` | Productos leídos de PostgreSQL | `Invoke-RestMethod http://localhost:8080/api/products` |
| `06-variables-entorno.png` | Variables configuradas, sin contraseñas reales | el archivo `.env` local |

> Ninguna captura ni log debe mostrar la contraseña real de la base de datos.
> En `.env` la contraseña es un valor local de desarrollo y `.env` está en `.gitignore`.
