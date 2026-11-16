# Prueba los endpoints del backend (debe estar corriendo con: mvn spring-boot:run)
# Uso (PowerShell):  .\scripts\verify.ps1
param(
    [string]$Base = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")

$Headers = @{ "Content-Type" = "application/json" }

# Se usa Invoke-WebRequest y se devuelve el cuerpo crudo: asi se ve el JSON
# exactamente como lo devuelve el servidor, sin el envoltorio value/Count que
# PowerShell anade al serializar arrays.
function Get-Json($path, $method = "GET", $body = $null) {
    $params = @{ Uri = "$Base$path"; Method = $method; UseBasicParsing = $true; TimeoutSec = 15 }
    if ($body) { $params.Body = $body; $params.Headers = $Headers }
    $resp = Invoke-WebRequest @params
    # Segun el tipo de contenido, .Content puede venir como string o como byte[].
    if ($resp.Content -is [byte[]]) { return [System.Text.Encoding]::UTF8.GetString($resp.Content) }
    return [string]$resp.Content
}

function Show($titulo, $resultado) {
    Write-Host ""
    Write-Host "--- $titulo" -ForegroundColor Cyan
    if ($resultado) { Write-Host $resultado } else { Write-Host "(sin respuesta)" -ForegroundColor Red }
}

try {
    Show "GET /api/db/status"   (Get-Json "/api/db/status")
    Show "GET /actuator/health" (Get-Json "/actuator/health")
    Show "POST /api/products"   (Get-Json "/api/products" "POST" '{"name":"Agua 600ml","category":"Bebidas frias","unitPrice":2500}')
    Show "POST /api/weather"    (Get-Json "/api/weather" "POST" '{"city":"Bogota","observationDate":"2026-11-16","temperatureC":14.5,"rainfallMm":6.2,"humidityPct":82,"weatherCondition":"Lluvia"}')
    Show "GET /api/products"    (Get-Json "/api/products")
    Show "GET /api/weather?city=Bogota" (Get-Json "/api/weather?city=Bogota")
    Write-Host ""
    Write-Host "Todas las consultas respondieron correctamente." -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Verifique que el backend este corriendo (mvn spring-boot:run) y que la base de datos responda."
    exit 1
}
