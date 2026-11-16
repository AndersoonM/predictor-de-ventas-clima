#!/usr/bin/env bash
# Prueba los endpoints del backend (debe estar corriendo con: mvn spring-boot:run)
BASE="${1:-http://localhost:8080}"
H='Content-Type: application/json'

echo "--- GET /api/db/status";      curl -sS "$BASE/api/db/status";      echo; echo
echo "--- GET /actuator/health";    curl -sS "$BASE/actuator/health";    echo; echo
echo "--- POST /api/products";      curl -sS -X POST -H "$H" -d '{"name":"Agua 600ml","category":"Bebidas frias","unitPrice":2500}' "$BASE/api/products"; echo; echo
echo "--- POST /api/weather";       curl -sS -X POST -H "$H" -d '{"city":"Bogota","observationDate":"2026-11-16","temperatureC":14.5,"rainfallMm":6.2,"humidityPct":82,"weatherCondition":"Lluvia"}' "$BASE/api/weather"; echo; echo
echo "--- GET /api/products";       curl -sS "$BASE/api/products";       echo; echo
echo "--- GET /api/weather?city=Bogota"; curl -sS "$BASE/api/weather?city=Bogota"; echo
