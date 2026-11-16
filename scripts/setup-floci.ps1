# Levanta Floci, crea la instancia RDS (PostgreSQL) y deja el .env sincronizado.
# Uso (PowerShell):  .\scripts\setup-floci.ps1
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")

function Need($cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: '$cmd' no esta instalado o no esta en el PATH" -ForegroundColor Red
        if ($cmd -eq "aws") {
            Write-Host "  Instalelo con:  winget install --id Amazon.AWSCLI -e" -ForegroundColor Yellow
            Write-Host "  (tambien se puede instalar desde https://aws.amazon.com/cli/)" -ForegroundColor Yellow
        }
        exit 1
    }
}
Need docker
Need aws

if (-not (Test-Path .env)) { Copy-Item .env.example .env; Write-Host "Se creo .env a partir de .env.example" }

# Cargar .env como variables de entorno de esta sesion
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*)$') { Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2].Trim() }
}

function Invoke-Aws { aws --endpoint-url $env:AWS_ENDPOINT_URL @args }

Write-Host "`n==> 1/5 Iniciando Floci (docker compose up -d)"
docker compose up -d
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: docker compose fallo" -ForegroundColor Red; exit 1 }

Write-Host "`n==> 2/5 Esperando a que la API de Floci responda en $env:AWS_ENDPOINT_URL"
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    Invoke-Aws rds describe-db-instances *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; Write-Host "Floci listo."; break }
    Start-Sleep -Seconds 2
}
if (-not $ready) { Write-Host "ERROR: Floci no respondio. Revise 'docker compose logs floci'." -ForegroundColor Red; exit 1 }

Write-Host "`n==> 3/5 Creando instancia RDS PostgreSQL '$env:DB_INSTANCE_ID' (si no existe)"
Invoke-Aws rds describe-db-instances --db-instance-identifier $env:DB_INSTANCE_ID *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "La instancia ya existe, no se vuelve a crear."
} else {
    Invoke-Aws rds create-db-instance `
        --db-instance-identifier $env:DB_INSTANCE_ID `
        --db-instance-class db.t3.micro `
        --engine postgres `
        --master-username $env:DB_USER `
        --master-user-password $env:DB_PASSWORD `
        --db-name $env:DB_NAME `
        --allocated-storage 20 `
        --port $env:DB_PORT | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: no se pudo crear la instancia" -ForegroundColor Red; exit 1 }
    Write-Host "Instancia solicitada (la primera vez se descarga la imagen postgres:16-alpine)."
}

Write-Host "`n==> 4/5 Esperando estado 'available'"
$available = $false
for ($i = 0; $i -lt 120; $i++) {
    $status = (Invoke-Aws rds describe-db-instances --db-instance-identifier $env:DB_INSTANCE_ID `
                --query "DBInstances[0].DBInstanceStatus" --output text)
    Write-Host "  estado: $status"
    if ($status -eq "available") { $available = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $available) { Write-Host "ERROR: la instancia no llego a 'available'." -ForegroundColor Red; exit 1 }

Write-Host "`n==> 5/5 Sincronizando puerto real en .env y probando conexion TCP"
$port = (Invoke-Aws rds describe-db-instances --db-instance-identifier $env:DB_INSTANCE_ID `
          --query "DBInstances[0].Endpoint.Port" --output text).Trim()
(Get-Content .env) | Where-Object { $_ -notmatch '^DB_PORT=' } | Set-Content .env -Encoding ascii
Add-Content .env "DB_PORT=$port" -Encoding ascii

$open = $false
for ($i = 0; $i -lt 60; $i++) {
    if ((Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue).TcpTestSucceeded) { $open = $true; break }
    Start-Sleep -Seconds 1
}
if (-not $open) { Write-Host "ERROR: el puerto $port no acepta conexiones." -ForegroundColor Red; exit 1 }

Write-Host "`nListo. Base de datos disponible en:"
Write-Host "  jdbc:postgresql://localhost:$port/$env:DB_NAME   (usuario: $env:DB_USER)"
Write-Host "`nSiguiente paso:  mvn spring-boot:run"
