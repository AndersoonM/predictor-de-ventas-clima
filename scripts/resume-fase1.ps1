# Reanuda el entregable de la fase 1 despues de reiniciar el equipo.
# Uso (PowerShell):  .\scripts\resume-fase1.ps1
#
# Encadena: Docker -> Floci + RDS -> backend -> evidencia -> commit.
# Es idempotente: se puede volver a ejecutar sin romper nada.
param(
    [switch]$SkipPush,
    [switch]$KeepBackendRunning
)

$ErrorActionPreference = "Continue"
$root = Join-Path $PSScriptRoot ".."
Set-Location $root

function Step($n) { Write-Host "`n==> $n" -ForegroundColor Cyan }
function Ok($m) { Write-Host "    [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    [!] $m" -ForegroundColor Yellow }

# --- 0. Entorno base: AWS CLI y GitHub CLI ---
Step "0/6 Verificando herramientas"
$env:PATH = "$env:ProgramFiles\Amazon\AWSCLIV2;C:\Program Files\GitHub CLI;$env:PATH"
foreach ($tool in @("docker", "aws", "gh", "java", "mvn", "git")) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) { Ok $tool }
    else { Warn "$tool no esta en el PATH"; exit 1 }
}

# --- 1. Virtualizacion habilitada ---
Step "1/6 Comprobando la virtualizacion (Virtual Machine Platform)"
$vmcompute = Get-Service vmcompute -ErrorAction SilentlyContinue
$hns       = Get-Service hns       -ErrorAction SilentlyContinue
if ($vmcompute -and $hns) {
    Ok "vmcompute y hns presentes (la caracteristica quedo habilitada)"
} else {
    Warn "Falta Virtual Machine Platform. Ejecuta como Administrador:"
    Write-Host "      dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart" -ForegroundColor Yellow
    Write-Host "      y reinicia el equipo." -ForegroundColor Yellow
    exit 1
}

# --- 2. Docker Desktop ---
Step "2/6 Levantando Docker Desktop"
if (-not (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue)) {
    $dd = "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
    if (Test-Path $dd) { Start-Process -FilePath $dd; Ok "Docker Desktop arrancando..." }
    else { Warn "No se encontro Docker Desktop en $dd"; exit 1 }
} else { Ok "Docker Desktop ya estaba corriendo" }

$dockerOk = $false
for ($i = 0; $i -lt 60; $i++) {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { $dockerOk = $true; break }
    Start-Sleep -Seconds 5
}
if (-not $dockerOk) { Warn "Docker no respondio en 5 minutos"; exit 1 }
Ok "Docker operativo: $(docker --version)"

# --- 3. Floci + RDS ---
Step "3/6 Inicializando Floci y la instancia RDS"
& (Join-Path $PSScriptRoot "setup-floci.ps1")
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { Warn "setup-floci devolvio $LASTEXITCODE"; }

# --- 4. Evidencia (incluye levantar y detener el backend) ---
Step "4/6 Generando la evidencia en docs/evidencias/"
$evArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "collect-evidence.ps1"))
if ($KeepBackendRunning) { $evArgs += "-KeepBackendRunning" }
& powershell @evArgs
if ($LASTEXITCODE -ne 0) { Warn "collect-evidence devolvio $LASTEXITCODE" }

# --- 5. Commit ---
Step "5/6 Guardando la evidencia en git"
git add -A
git status --short | ForEach-Object { Write-Host "    $_" }
git commit -q -m "docs: evidencia de la fase 1 (Floci, RDS, conexion y tablas)" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Ok "commit realizado" } else { Warn "nada que commitear o error en git" }
git log --oneline -1

# --- 6. Push ---
Step "6/6 Publicando en GitHub"
if ($SkipPush) { Warn "push omitido (--SkipPush)" }
else {
    git push origin main 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Host "    $_" }
    Ok "Repositorio: https://github.com/AndersoonM/predictor-de-ventas-clima"
}

Write-Host ""
Write-Host "Entregable de la fase 1 completado." -ForegroundColor Green
Write-Host "  Evidencia : docs/evidencias/"
Write-Host "  Repo      : https://github.com/AndersoonM/predictor-de-ventas-clima" -ForegroundColor Cyan
