#!/bin/bash
set -e

echo "Waiting for Kafka brokers to be ready..."
sleep 15

echo "============================================================"
echo "Setting up ACLs for Debezium CDC"
echo "============================================================"

BOOTSTRAP_SERVER="kafka-broker-1:9093"

# Create temporary config file with SCRAM-SHA-256 credentials
cat > /tmp/admin.properties <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="${KAFKA_ADMIN_PASS}";
EOF

COMMAND_CONFIG="--command-config /tmp/admin.properties"

echo ""
echo "Setting up ACLs for Debezium user..."
echo ""

# ============================================================
# Debezium ACLs (CDC Producer)
# ============================================================

# Allow Debezium to produce to all CDC topics (db.* pattern)
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --add \
  --allow-principal "User:debezium" \
  --operation Write \
  --operation Create \
  --operation Describe \
  --topic 'db' \
  --resource-pattern-type prefixed

# Allow Debezium to consume from CDC topics (needed for sink connectors)
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --add \
  --allow-principal "User:debezium" \
  --operation Read \
  --topic 'db' \
  --resource-pattern-type prefixed

# Allow Debezium to produce to heartbeat topics
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --add \
  --allow-principal "User:debezium" \
  --operation Write \
  --operation Create \
  --operation Describe \
  --topic '__debezium-heartbeat' \
  --resource-pattern-type prefixed

# Allow Debezium to produce to DLQ topics
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --add \
  --allow-principal "User:debezium" \
  --operation Write \
  --operation Create \
  --operation Describe \
  --topic 'dlq-' \
  --resource-pattern-type prefixed

# Allow Debezium to manage schema history topics
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --add \
  --allow-principal "User:debezium" \
  --operation All \
  --topic 'schema-changes' \
  --resource-pattern-type prefixed

# Allow Debezium to create and manage Connect internal topics
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --add \
  --allow-principal "User:debezium" \
  --operation All \
  --topic "debezium_connect_configs" \
  --topic "debezium_connect_offsets" \
  --topic "debezium_connect_statuses"

# Allow Debezium to manage consumer groups (debezium-* pattern)
# Note: GROUP only supports [READ, DESCRIBE, ALL, DESCRIBE_CONFIGS, ALTER_CONFIGS, DELETE]
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --add \
  --allow-principal "User:debezium" \
  --operation Read \
  --operation Describe \
  --group 'debezium' \
  --resource-pattern-type prefixed

# Allow Debezium to manage Connect consumer groups (connect-* pattern)
# Needed for sink connectors which use connect-<connector-name> groups
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --add \
  --allow-principal "User:debezium" \
  --operation Read \
  --operation Describe \
  --group 'connect' \
  --resource-pattern-type prefixed

# Allow Debezium cluster operations (needed for Connect)
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --add \
  --allow-principal "User:debezium" \
  --operation Create \
  --cluster

echo "✅ ACLs for debezium configured"

echo ""
echo "============================================================"
echo "ACL Setup Complete!"
echo "============================================================"
echo ""
echo "Listing all ACLs for verification..."
kafka-acls --bootstrap-server $BOOTSTRAP_SERVER \
  $COMMAND_CONFIG \
  --list

echo ""
echo "============================================================"
