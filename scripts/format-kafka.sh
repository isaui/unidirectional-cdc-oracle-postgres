#!/bin/bash
set -e

echo "=================================================="
echo "Kafka KRaft Storage Formatter"
echo "=================================================="

# Check if cluster ID is provided
if [ -z "$CLUSTER_ID" ]; then
  echo "ERROR: CLUSTER_ID environment variable not set!"
  exit 1
fi

echo "Cluster ID: $CLUSTER_ID"
echo ""

# Create temporary server properties
cat > /tmp/format-server.properties <<EOF
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@kafka-broker-1:19093
listeners=SASL_PLAINTEXT://0.0.0.0:9093,CONTROLLER://kafka-broker-1:19093
advertised.listeners=SASL_PLAINTEXT://kafka-broker-1:9093
inter.broker.listener.name=SASL_PLAINTEXT
controller.listener.names=CONTROLLER
listener.security.protocol.map=SASL_PLAINTEXT:SASL_PLAINTEXT,CONTROLLER:SASL_PLAINTEXT
sasl.enabled.mechanisms=SCRAM-SHA-256,PLAIN
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-256
sasl.mechanism.controller.protocol=PLAIN
log.dirs=/var/lib/kafka/data
EOF

echo "Formatting Kafka storage with SCRAM users..."
echo ""

# Format storage with SCRAM users (only debezium and admin)
kafka-storage format \
  --cluster-id="$CLUSTER_ID" \
  --config=/tmp/format-server.properties \
  --add-scram "SCRAM-SHA-256=[name=admin,password=${KAFKA_ADMIN_PASS}]" \
  --add-scram "SCRAM-SHA-256=[name=debezium,password=${DEBEZIUM_PASSWORD}]" \
  --ignore-formatted

echo ""
echo "✅ Kafka storage formatted successfully!"
echo ""
echo "SCRAM Users Created:"
echo "  - admin (Super User)"
echo "  - debezium (CDC Producer)"
echo ""
echo "=================================================="
