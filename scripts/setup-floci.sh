#!/usr/bin/env bash
# Levanta Floci, crea la instancia RDS (PostgreSQL) y deja el .env sincronizado.
# Uso: ./scripts/setup-floci.sh
set -euo pipefail
cd "$(dirname "$0")/.."

log() { printf '\n==> %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' no esta instalado o no esta en el PATH"; exit 1; }; }

need docker
need aws

[ -f .env ] || { cp .env.example .env; echo "Se creo .env a partir de .env.example"; }
set -a; source .env; set +a

aws_local() { aws --endpoint-url "$AWS_ENDPOINT_URL" "$@"; }

log "1/5 Iniciando Floci (docker compose up -d)"
docker compose up -d

log "2/5 Esperando a que la API de Floci responda en $AWS_ENDPOINT_URL"
for i in $(seq 1 60); do
  if aws_local rds describe-db-instances >/dev/null 2>&1; then echo "Floci listo."; break; fi
  [ "$i" -eq 60 ] && { echo "ERROR: Floci no respondio. Ejecute 'docker compose logs floci' o 'floci doctor'."; exit 1; }
  sleep 2
done

log "3/5 Creando instancia RDS PostgreSQL '$DB_INSTANCE_ID' (si no existe)"
if aws_local rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" >/dev/null 2>&1; then
  echo "La instancia ya existe, no se vuelve a crear."
else
  aws_local rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --master-username "$DB_USER" \
    --master-user-password "$DB_PASSWORD" \
    --db-name "$DB_NAME" \
    --allocated-storage 20 \
    --port "$DB_PORT" >/dev/null
  echo "Instancia solicitada (la primera vez se descarga la imagen postgres:16-alpine)."
fi

log "4/5 Esperando estado 'available'"
for i in $(seq 1 120); do
  STATUS=$(aws_local rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" \
           --query 'DBInstances[0].DBInstanceStatus' --output text)
  echo "  estado: $STATUS"
  [ "$STATUS" = "available" ] && break
  [ "$i" -eq 120 ] && { echo "ERROR: la instancia no llego a 'available'."; exit 1; }
  sleep 2
done

log "5/5 Sincronizando puerto real en .env y probando conexion TCP"
PORT=$(aws_local rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" \
       --query 'DBInstances[0].Endpoint.Port' --output text)
grep -v '^DB_PORT=' .env > .env.tmp && echo "DB_PORT=$PORT" >> .env.tmp && mv .env.tmp .env
for i in $(seq 1 60); do
  if (echo > "/dev/tcp/localhost/$PORT") 2>/dev/null; then echo "Puerto $PORT aceptando conexiones."; break; fi
  [ "$i" -eq 60 ] && { echo "ERROR: el puerto $PORT no acepta conexiones."; exit 1; }
  sleep 1
done

cat <<MSG

Listo. Base de datos disponible en:
  jdbc:postgresql://localhost:$PORT/$DB_NAME   (usuario: $DB_USER)

Siguiente paso:  mvn spring-boot:run
MSG
