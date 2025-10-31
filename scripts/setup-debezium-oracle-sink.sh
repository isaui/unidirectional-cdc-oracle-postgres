#!/bin/sh
set -e

echo "=================================================="
echo "Debezium Oracle Sink Connector Setup"
echo "=================================================="

echo "Waiting for Debezium Connect to be ready..."
sleep 10

CONNECT_URL="http://debezium-connect:8083"
CONNECTOR_NAME="oracle-sink-connector"

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

if [ "$CDC_MODE" != "POSTGRES" ]; then
    echo "⚠️  Skipping Oracle Sink deployment (CDC_MODE=$CDC_MODE)"
    echo "ℹ️  Oracle Sink only active when CDC_MODE=POSTGRES"
    echo "=================================================="
    exit 0
fi

echo "✅ CDC_MODE=POSTGRES - Deploying Oracle Sink connector..."

# Deploy connector with env var substitution
echo "Deploying Oracle Sink connector..."

# Substitute environment variables in connector config
CONNECTOR_CONFIG=$(cat /config/oracle-sink-connector.json | \
  sed "s/\${ORACLE_DATABASE}/${ORACLE_DATABASE}/g" | \
  sed "s/\${ORACLE_APP_USER}/${ORACLE_APP_USER}/g" | \
  sed "s/\${ORACLE_APP_PASSWORD}/${ORACLE_APP_PASSWORD}/g")

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
echo "✅ Oracle Sink connector deployed!"
echo "=================================================="
echo "Connector Name: ${CONNECTOR_NAME}"
echo "Connect URL: ${CONNECT_URL}"
echo "Source Topics: db.postgres.public.users, db.postgres.public.user_activities"
echo "Target Tables: users, user_activities (Oracle)"
echo "=================================================="
