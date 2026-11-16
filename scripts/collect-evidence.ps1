# Genera la evidencia del entregable en docs/evidencias/.
# Uso (PowerShell):  .\scripts\collect-evidence.ps1
#
# Requisitos: Docker corriendo, AWS CLI en el PATH, .env generado, base de datos
# creada (scripts/setup-floci.ps1). Si el backend ya esta corriendo en el puerto
# 8080, se reutiliza; si no, se levanta aqui y se detiene al terminar.
param(
    [string]$Base = "http://localhost:8080",
    [switch]$KeepBackendRunning
)

$ErrorActionPreference = "Continue"
$root = Join-Path $PSScriptRoot ".."
Set-Location $root

$ev = Join-Path $root "docs\evidencias"
$logs = Join-Path $ev "logs"
New-Item -ItemType Directory -Force -Path $ev, $logs | Out-Null

$startedByUs = $null

function Step($n) { Write-Host "`n==> $n" -ForegroundColor Cyan }
function Save($file, $content) {
    $path = Join-Path $ev $file
    Set-Content -Path $path -Value $content -Encoding utf8
    Write-Host "    guardado: docs/evidencias/$file"
}

Step "0/8 Comprobando el entorno"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Host "ERROR: falta docker" -ForegroundColor Red; exit 1 }
if (-not (Get-Command aws -ErrorAction SilentlyContinue))   { Write-Host "ERROR: falta aws" -ForegroundColor Red; exit 1 }
if (-not (Test-Path .env))                                 { Write-Host "ERROR: falta .env (ejecute setup-floci.ps1)" -ForegroundColor Red; exit 1 }

docker info *> $null
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Docker no esta corriendo" -ForegroundColor Red; exit 1 }

# --- Cargar .env como variables de esta sesion ---
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*)$') { Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2].Trim() }
}
$endpoint = if ($env:AWS_ENDPOINT_URL) { $env:AWS_ENDPOINT_URL } else { "http://localhost:4566" }

Step "1/8 Evidencia de inicializacion: contenedores de Docker"
$dockerPs = docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
$composePs = docker compose ps
Save "01-floci-contenedores.txt" @(
    "# Evidencia 1 - Inicializacion de Floci (emulador de AWS local)",
    "# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "",
    "`$ docker ps",
    $dockerPs,
    "",
    "`$ docker compose ps",
    $composePs
)

Step "2/8 Evidencia de la instancia RDS (PostgreSQL) en Floci"
$rdsRaw = aws --endpoint-url $endpoint rds describe-db-instances --db-instance-identifier $env:DB_INSTANCE_ID 2>&1 | Out-String
$rds = ($rdsRaw | ConvertFrom-Json).DBInstances[0]
Save "02-rds-instancia.json" $rdsRaw
Write-Host "    instancia: $($rds.DBInstanceIdentifier)  estado: $($rds.DBInstanceStatus)  puerto: $($rds.Endpoint.Port)"

Step "3/8 Asegurando que el backend este corriendo"
$health = $null
try { $health = Invoke-RestMethod "$Base/actuator/health" -Method Get -TimeoutSec 3 } catch { $health = $null }

if ($health) {
    Write-Host "    el backend ya estaba corriendo en $Base, se reutiliza"
    $logCompleto = Join-Path $logs "springboot-arranque-completo.log"
    if (-not (Test-Path $logCompleto)) {
        Set-Content -Path $logCompleto -Value "(El backend ya estaba corriendo antes de generar la evidencia; este log no se capturo.)" -Encoding utf8
    }
} else {
    Write-Host "    levantando: mvn spring-boot:run"
    $logCompleto = Join-Path $logs "springboot-arranque-completo.log"
    $logErr = Join-Path $logs "springboot-arranque.err.log"
    $startedByUs = Start-Process -FilePath "mvn.cmd" -ArgumentList "spring-boot:run" `
                    -WorkingDirectory $root -PassThru -NoNewWindow `
                    -RedirectStandardOutput $logCompleto -RedirectStandardError $logErr

    $ok = $false
    for ($i = 0; $i -lt 90; $i++) {
        Start-Sleep -Seconds 2
        try {
            $h = Invoke-RestMethod "$Base/actuator/health" -Method Get -TimeoutSec 3
            if ($h.status -eq "UP") { $ok = $true; break }
        } catch { }
    }
    if (-not $ok) {
        Write-Host "ERROR: el backend no levanto en 180s. Revise $logCompleto" -ForegroundColor Red
        Get-Content $logCompleto -Tail 40 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        if ($startedByUs) { taskkill /PID $startedByUs.Id /T /F *> $null }
        exit 1
    }
    Write-Host "    backend arriba"
}

Step "4/8 Extrayendo el bloque de conexion exitosa del log de arranque"
$logLines = @()
if (Test-Path (Join-Path $logs "springboot-arranque-completo.log")) {
    $logLines = Get-Content (Join-Path $logs "springboot-arranque-completo.log")
}
$clave = $logLines | Select-String -Pattern "CONEXION EXITOSA|Motor\s+:|URL\s+:|Usuario\s+:|Se cargaron|Tomcat started|Started WeatherSalesApplication|products of example|productos de ejemplo" -Context 0, 0
$extracto = @(
    "# Evidencia 3 - Arranque de Spring Boot con conexion a la base de datos",
    "# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "",
    "Extracto del log de arranque (log completo en docs/evidencias/logs/):",
    ""
) + ($clave | ForEach-Object { $_.Line })
Save "03-springboot-arranque.log" ($extracto -join "`r`n")

Step "5/8 Consultando los endpoints de la API"
$dbStatus  = Invoke-RestMethod "$Base/api/db/status"   -Method Get
$healthNow = Invoke-RestMethod "$Base/actuator/health" -Method Get
$products  = Invoke-RestMethod "$Base/api/products"   -Method Get
Save "04-db-status.json"      ($dbStatus  | ConvertTo-Json -Depth 5)
Save "05-actuator-health.json" ($healthNow | ConvertTo-Json -Depth 5)
Save "06-productos.json"      ($products  | ConvertTo-Json -Depth 5)

Write-Host "    db.status = $($dbStatus.status) / $($dbStatus.database) / $($dbStatus.version)"
Write-Host "    productos devueltos = $($products.Count)"

Step "6/8 Tablas creadas en la base de datos"
$tablas = @()
try {
    $cont = docker exec (docker ps --filter "label=io.floci.resource-id=$env:DB_INSTANCE_ID" --format "{{.Names}}" | Select-Object -First 1) `
            psql -U $env:DB_USER -d $env:DB_NAME -c "\dt" 2>&1 | Out-String
    $tablas = $cont
} catch { $tablas = "(no se pudo listar via psql: $($_.Exception.Message))" }
Save "07-tablas-bd.txt" $tablas

Step "7/8 Configuracion del entorno (contrasena enmascarada)"
$mask = if ($env:DB_PASSWORD) { ($env:DB_PASSWORD -replace '(?<=^.{2}).*$', '********') } else { "(sin definir)" }
$cfg = @(
    "# Evidencia 7 - Configuracion del entorno",
    "# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "",
    "## Versiones",
    "",
    "```",
    "Java  : $((java -version 2>&1) -join ' ')",
    "Maven : $((mvn -v 2>&1 | Select-Object -First 1) -join '')",
    "Docker: $((docker --version) -join '')",
    "AWS   : $((aws --version) -join '')",
    "```",
    "",
    "## Variables de entorno efectivas (contrasena enmascarada)",
    "",
    "| Variable | Valor |",
    "|---|---|",
    "| AWS_ENDPOINT_URL | $endpoint |",
    "| AWS_DEFAULT_REGION | $($env:AWS_DEFAULT_REGION) |",
    "| DB_INSTANCE_ID | $($env:DB_INSTANCE_ID) |",
    "| DB_HOST | $($env:DB_HOST) |",
    "| DB_PORT | $($env:DB_PORT) |",
    "| DB_NAME | $($env:DB_NAME) |",
    "| DB_USER | $($env:DB_USER) |",
    "| DB_PASSWORD | $mask |",
    "| SERVER_PORT | $($env:SERVER_PORT) |",
    "",
    "> La contrasena real vive solo en el archivo `.env`, que esta en `.gitignore` y nunca se versiona.",
    "",
    "## URL JDBC efectiva",
    "",
    '```',
    "jdbc:postgresql://$($env:DB_HOST):$($env:DB_PORT)/$($env:DB_NAME)?sslmode=disable",
    '```'
)
Save "08-configuracion.md" ($cfg -join "`r`n")

Step "8/8 Deteniendo el backend (si lo levanto este script)"
if ($startedByUs) {
    if ($KeepBackendRunning) {
        Write-Host "    se deja corriendo (se pidio -KeepBackendRunning)"
    } else {
        taskkill /PID $startedByUs.Id /T /F *> $null
        Write-Host "    backend detenido"
    }
}

Write-Host ""
Write-Host "Evidencia completa en docs/evidencias/" -ForegroundColor Green
Get-ChildItem $ev -File | Sort-Object Name | ForEach-Object { Write-Host "  $($_.Name)" }
