#!/bin/sh
set -e

echo "=================================================="
echo "Debezium PostgreSQL Sink Connector Setup"
echo "=================================================="

echo "Waiting for Debezium Connect to be ready..."
sleep 10

CONNECT_URL="http://debezium-connect:8083"
CONNECTOR_NAME="postgres-sink-connector"

# CLEANUP FIRST - Delete old connector if exists
echo "Checking if connector exists..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${CONNECT_URL}/connectors/${CONNECTOR_NAME})

if [ "$STATUS" = "200" ]; then
    echo "Connector already exists. Deleting old connector..."
    curl -s -X DELETE ${CONNECT_URL}/connectors/${CONNECTOR_NAME} > /dev/null
    echo "✅ Old connector deleted"
    sleep 5
fi

# NOW CHECK CDC_MODE
CDC_MODE=${CDC_MODE:-POSTGRES}
echo "CDC_MODE: $CDC_MODE"

if [ "$CDC_MODE" != "ORACLE" ]; then
    echo "⚠️  Skipping PostgreSQL Sink deployment (CDC_MODE=$CDC_MODE)"
    echo "ℹ️  PostgreSQL Sink only active when CDC_MODE=ORACLE"
    echo "=================================================="
    exit 0
fi

echo "✅ CDC_MODE=ORACLE - Deploying PostgreSQL Sink connector..."

# Deploy connector with env var substitution
echo "Deploying PostgreSQL Sink connector..."

# Substitute environment variables in connector config
CONNECTOR_CONFIG=$(cat /config/postgres-sink-connector.json | \
  sed "s/\${POSTGRES_DB}/${POSTGRES_DB}/g" | \
  sed "s/\${POSTGRES_USER}/${POSTGRES_USER}/g" | \
  sed "s/\${POSTGRES_PASSWORD}/${POSTGRES_PASSWORD}/g" | \
  sed "s/\${ORACLE_APP_USER}/${ORACLE_APP_USER}/g")

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST ${CONNECT_URL}/connectors \
  -H "Content-Type: application/json" \
  -d "${CONNECTOR_CONFIG}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Connector deployed successfully (HTTP $HTTP_CODE)"
else
    echo "❌ Failed to deploy connector (HTTP $HTTP_CODE)"
    echo "$RESPONSE" | head -n-1
fi

sleep 5

# Check connector status
echo ""
echo "Checking connector status..."
curl -s ${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status | grep -o '"state":"[^"]*"' || echo "Status check failed"

echo ""
echo "=================================================="
echo "✅ PostgreSQL Sink connector deployed!"
echo "=================================================="
echo "Connector Name: ${CONNECTOR_NAME}"
echo "Connect URL: ${CONNECT_URL}"
echo "Source Topics: db.oracle.${ORACLE_APP_USER}.USERS, db.oracle.${ORACLE_APP_USER}.USER_ACTIVITIES"
echo "Target Tables: users, user_activities (PostgreSQL)"
echo "=================================================="
