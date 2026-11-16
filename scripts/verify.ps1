# Prueba los endpoints del backend (debe estar corriendo con: mvn spring-boot:run)
# Uso (PowerShell):  .\scripts\verify.ps1
param(
    [string]$Base = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")

$Headers = @{ "Content-Type" = "application/json" }

function Show($titulo, $resultado) {
    Write-Host ""
    Write-Host "--- $titulo" -ForegroundColor Cyan
    if ($resultado) { Write-Host $resultado } else { Write-Host "(sin respuesta)" -ForegroundColor Red }
}

try {
    Show "GET /api/db/status"   (Invoke-RestMethod "$Base/api/db/status"      -Method Get | ConvertTo-Json -Depth 5)
    Show "GET /actuator/health" (Invoke-RestMethod "$Base/actuator/health"    -Method Get | ConvertTo-Json -Depth 5)
    Show "POST /api/products"   (Invoke-RestMethod "$Base/api/products"      -Method Post -Headers $Headers `
                                      -Body '{"name":"Agua 600ml","category":"Bebidas frias","unitPrice":2500}' | ConvertTo-Json -Depth 5)
    Show "POST /api/weather"    (Invoke-RestMethod "$Base/api/weather"       -Method Post -Headers $Headers `
                                      -Body '{"city":"Bogota","observationDate":"2026-11-16","temperatureC":14.5,"rainfallMm":6.2,"humidityPct":82,"weatherCondition":"Lluvia"}' | ConvertTo-Json -Depth 5)
    Show "GET /api/products"    (Invoke-RestMethod "$Base/api/products"      -Method Get | ConvertTo-Json -Depth 5)
    Show "GET /api/weather?city=Bogota" (Invoke-RestMethod "$Base/api/weather?city=Bogota" -Method Get | ConvertTo-Json -Depth 5)
    Write-Host ""
    Write-Host "Todas las consultas respondieron correctamente." -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Verifique que el backend este corriendo (mvn spring-boot:run) y que la base de datos responda."
    exit 1
}
