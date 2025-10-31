#!/bin/sh
set -e

echo "=================================================="
echo "Debezium Oracle CDC Connector Setup"
echo "=================================================="

echo "Waiting for Debezium Connect to be ready..."
sleep 10

CONNECT_URL="http://debezium-connect:8083"
CONNECTOR_NAME="oracle-cdc-connector"

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
    echo "⚠️  Skipping Oracle CDC deployment (CDC_MODE=$CDC_MODE)"
    echo "ℹ️  Oracle CDC only active when CDC_MODE=ORACLE"
    echo "=================================================="
    exit 0
fi

echo "✅ CDC_MODE=ORACLE - Deploying Oracle CDC connector..."

# Deploy connector with env var substitution
echo "Deploying Oracle Source CDC connector..."

# Substitute environment variables in connector config
CONNECTOR_CONFIG=$(cat /config/oracle-source-connector.json | \
  sed "s/\${ORACLE_DATABASE}/${ORACLE_DATABASE}/g" | \
  sed "s/\${ORACLE_APP_USER}/${ORACLE_APP_USER}/g" | \
  sed "s/\${ORACLE_CDC_PASSWORD}/${ORACLE_CDC_PASSWORD}/g" | \
  sed "s/\${DEBEZIUM_PASSWORD}/${DEBEZIUM_PASSWORD}/g")

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST ${CONNECT_URL}/connectors \
  -H "Content-Type: application/json" \
  -d "${CONNECTOR_CONFIG}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Connector deployed successfully (HTTP $HTTP_CODE)"
else
    echo "❌ Failed to deploy connector (HTTP $HTTP_CODE)"
    echo "$RESPONSE" | head -n-1
    exit 1
fi

sleep 5

# Check connector status
echo ""
echo "Checking connector status..."
curl -s ${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status | grep -o '"state":"[^"]*"' || echo "Status check failed"

echo ""
echo "=================================================="
echo "✅ Oracle Source CDC connector deployed!"
echo "=================================================="
echo "Connector Name: ${CONNECTOR_NAME}"
echo "Connect URL: ${CONNECT_URL}"
echo "Source Tables: ${ORACLE_APP_USER}.USERS, ${ORACLE_APP_USER}.USER_ACTIVITIES"
echo "Target Topics: db.oracle.${ORACLE_APP_USER}.USERS, db.oracle.${ORACLE_APP_USER}.USER_ACTIVITIES"
echo "=================================================="
