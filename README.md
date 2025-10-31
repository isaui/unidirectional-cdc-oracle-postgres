# Debezium CDC: Oracle / PostgreSQL

Production-ready unidirectional Change Data Capture (CDC) system using Debezium, Kafka, Oracle XE 21c, and PostgreSQL. Supports either Oracle-to-Postgres OR Postgres-to-Oracle replication (one direction at a time) with SCRAM-SHA-256 authentication and ACL security.

## Features

- **Unidirectional CDC**: Configure Oracle to Postgres OR Postgres to Oracle (not both simultaneously)
- **Oracle ARCHIVELOG**: Automatic enablement via startup script
- **LogMiner CDC**: Real-time Oracle change capture
- **SASL Authentication**: SCRAM-SHA-256 security for Kafka
- **ACL Authorization**: Fine-grained topic and group permissions
- **Schema Compatibility**: Properly mapped Oracle and Postgres types
- **Kafka UI**: Web interface for monitoring
- **Docker Compose**: Single-command deployment

## Architecture

### Oracle → PostgreSQL Mode (CDC_MODE=ORACLE)
```
┌──────────────────┐        ┌─────────────────────┐
│  Oracle XE 21c   │───CDC──▶│  Kafka Cluster      │
│  - ARCHIVELOG    │        │  - KRaft Mode       │
│  - LogMiner      │        │  - SASL Auth        │
│  - C##DBZUSER    │        │  - Port 9093        │
└──────────────────┘        └─────────────────────┘
                                       │
                                       │ Topics: db.oracle.*
                                       ▼
                            ┌──────────────────────┐
                            │  Debezium Connect    │
                            │  - Source Connector  │
                            │  - Sink Connector    │
                            └──────────────────────┘
                                       │
                                       ▼
                            ┌──────────────────────┐
                            │  PostgreSQL 16       │
                            │  - Logical Repl.     │
                            │  - Port 5432         │
                            └──────────────────────┘
```

### PostgreSQL → Oracle Mode (CDC_MODE=POSTGRES)
```
┌──────────────────┐        ┌─────────────────────┐
│  PostgreSQL 16   │───CDC──▶│  Kafka Cluster      │
│  - WAL: logical  │        │  - KRaft Mode       │
│  - Port 5432     │        │  - SASL Auth        │
└──────────────────┘        └─────────────────────┘
                                       │
                                       │ Topics: db.postgres.*
                                       ▼
                            ┌──────────────────────┐
                            │  Debezium Connect    │
                            │  - Source Connector  │
                            │  - Sink Connector    │
                            └──────────────────────┘
                                       │
                                       ▼
                            ┌──────────────────────┐
                            │  Oracle XE 21c       │
                            │  - APPUSER schema    │
                            │  - Port 1521         │
                            └──────────────────────┘
```

## Security Features

### Implemented
- **SCRAM-SHA-256**: Secure Kafka authentication mechanism
- **ACL Authorization**: Fine-grained topic and group permissions
- **Oracle CDB User**: C##DBZUSER with LogMiner privileges
- **Kafka JAAS**: Separate admin and debezium users
- **Password Management**: Environment variable based

### Not Included (by design)
- TLS/SSL encryption (uses SASL_PLAINTEXT for simplicity)
- Multi-broker cluster (single node setup)
- mTLS authentication

## Quick Start

### 1. Setup Environment

```bash
# Copy environment template
cp .env-example .env

# Edit .env and set your passwords
nano .env
```

### 2. Start All Services

```bash
# Clean start (recommended first time)
docker compose down -v
docker compose up -d

# Check all services
docker compose ps

# Monitor logs
docker compose logs -f oracle
docker compose logs -f debezium-connect
```

### 3. Verify Oracle Setup

```bash
# Check ARCHIVELOG mode (should see "ARCHIVELOG")
docker compose exec oracle sqlplus -s / as sysdba <<EOF
SELECT LOG_MODE FROM V\$DATABASE;
EXIT;
EOF

# Verify CDC user
docker compose exec oracle sqlplus -s / as sysdba <<EOF
SELECT username, account_status FROM dba_users WHERE username = 'C##DBZUSER';
EXIT;
EOF
```

### 4. Check Connector Status

```bash
# Oracle CDC connector (if CDC_MODE=ORACLE)
docker compose exec debezium-connect curl -s http://localhost:8083/connectors/oracle-cdc-connector/status | jq

# PostgreSQL sink connector
docker compose exec debezium-connect curl -s http://localhost:8083/connectors/postgres-sink-connector/status | jq
```

### 5. Access Kafka UI

Open http://localhost:8080 in your browser:
- **Username**: `admin` (from `.env`)
- **Password**: `KAFKA_UI_PASSWORD` (from `.env`)

Monitor topics, messages, and connector status in real-time.

## CDC Mode Configuration

Set `CDC_MODE` in `.env` to control replication direction:

### Oracle → PostgreSQL (CDC_MODE=ORACLE)
```bash
CDC_MODE=ORACLE
```
- **Source**: Oracle XE (LogMiner CDC)
- **Sink**: PostgreSQL
- **Topics**: `db.oracle.APPUSER.*`
- **Connectors**: `oracle-cdc-connector` + `postgres-sink-connector`

### PostgreSQL → Oracle (CDC_MODE=POSTGRES)
```bash
CDC_MODE=POSTGRES
```
- **Source**: PostgreSQL (WAL replication)
- **Sink**: Oracle XE
- **Topics**: `db.postgres.public.*`
- **Connectors**: `postgres-cdc-connector` + `oracle-sink-connector`

**WARNING**: This is unidirectional replication only. Choose ONE direction. Running both directions simultaneously will cause replication loops and data corruption!

## User Credentials

| User | Password (from .env) | Role | Permissions |
|------|---------------------|------|-------------|
| **admin** | `KAFKA_ADMIN_PASS` | Super User | Full cluster access |
| **debezium** | `DEBEZIUM_PASSWORD` | CDC Producer | Write to `db.*` topics, Connect operations |

## ACL Permissions (Debezium)

The `debezium` user has the following permissions:

- **Write/Create** on `db.*` topics (CDC data)
- **Write/Create** on `__debezium-heartbeat.*` topics
- **Full access** to Connect internal topics:
  - `debezium_connect_configs`
  - `debezium_connect_offsets`
  - `debezium_connect_statuses`
- **Read/Write** on `debezium-*` consumer groups
- **Create** cluster operations

## Ports

| Port | Service | Protocol | Access |
|------|---------|----------|--------|
| 9093 | Kafka | SASL_PLAINTEXT | SCRAM-SHA-256 auth required |
| 8080 | Kafka UI | HTTP | Web interface |
| 8083 | Debezium Connect | HTTP | REST API |
| 5432 | PostgreSQL | Native | Database access |
| 1521 | Oracle XE | TNS | Database access |

**Note**: Kafka uses SASL_PLAINTEXT with SCRAM-SHA-256 authentication (no TLS).

## Environment Variables

See `.env-example` for all configuration options:

```bash
# Kafka Cluster
CLUSTER_ID=your-cluster-id
KAFKA_ADMIN_PASS=your-admin-password
DEBEZIUM_PASSWORD=your-debezium-password

# Kafka UI
KAFKA_UI_USERNAME=admin
KAFKA_UI_PASSWORD=your-ui-password

# CDC Mode
CDC_MODE=ORACLE  # or POSTGRES

# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-postgres-password
POSTGRES_DB=cdcdb

# Oracle
ORACLE_PASSWORD=your-oracle-sys-password
ORACLE_DATABASE=CDCDB
ORACLE_APP_USER=APPUSER
ORACLE_APP_PASSWORD=your-oracle-app-password
ORACLE_CDC_PASSWORD=your-oracle-cdc-password
```

## Database Schema

Both databases have identical schema structure with compatible types:

### users table

| Column | Oracle Type | Postgres Type |
|--------|-------------|---------------|
| id | NUMBER (identity) | BIGSERIAL |
| username | VARCHAR2(100) | VARCHAR(100) |
| email | VARCHAR2(255) | VARCHAR(255) |
| full_name | VARCHAR2(255) | VARCHAR(255) |
| status | VARCHAR2(20) | VARCHAR(20) |
| created_at | TIMESTAMP | TIMESTAMP |
| updated_at | TIMESTAMP | TIMESTAMP |

### user_activities table

| Column | Oracle Type | Postgres Type |
|--------|-------------|---------------|
| id | NUMBER (identity) | BIGSERIAL |
| user_id | NUMBER | BIGINT |
| activity_type | VARCHAR2(50) | VARCHAR(50) |
| description | CLOB | TEXT |
| ip_address | VARCHAR2(45) | VARCHAR(45) |
| user_agent | CLOB | TEXT |
| created_at | TIMESTAMP | TIMESTAMP |

**Type Compatibility**: All types properly mapped for unidirectional replication in either direction.

## Testing

### Test PostgreSQL

```bash
# Connect to database
docker compose exec postgres psql -U postgres -d cdcdb

# Check tables
\dt

# Insert test user
INSERT INTO users (username, email, full_name) 
VALUES ('test_user', 'test@example.com', 'Test User');

# Insert test activity
INSERT INTO user_activities (user_id, activity_type, description) 
VALUES (1, 'test_action', 'Testing CDC');

# Exit
\q
```

### Test Oracle

```bash
# Connect as APP USER
docker compose exec oracle sqlplus APPUSER/appuser123@//localhost:1521/CDCDB

# Check tables
SELECT table_name FROM user_tables;

# Insert test user
INSERT INTO USERS (username, email, full_name) 
VALUES ('oracle_user', 'oracle@example.com', 'Oracle User');
COMMIT;

# Insert test activity
INSERT INTO USER_ACTIVITIES (user_id, activity_type, description) 
VALUES (1, 'oracle_action', 'Testing Oracle CDC');
COMMIT;

# Exit
EXIT;
```

### Monitor CDC Replication

```bash
# Watch Kafka topics (Oracle mode)
docker compose exec kafka-broker kafka-console-consumer \
  --bootstrap-server localhost:9093 \
  --topic db.oracle.APPUSER.USERS \
  --from-beginning \
  --consumer.config /tmp/admin.properties

# Check sink database for replicated data
# If Oracle→Postgres, check PostgreSQL
docker compose exec postgres psql -U postgres -d cdcdb -c "SELECT * FROM users ORDER BY id DESC LIMIT 5;"

# If Postgres→Oracle, check Oracle
docker compose exec oracle sqlplus APPUSER/appuser123@//localhost:1521/CDCDB <<EOF
SELECT * FROM USERS ORDER BY ID DESC FETCH FIRST 5 ROWS ONLY;
EXIT;
EOF
```

### Create Test Topic

```bash
# Create admin properties file
cat > admin.properties <<EOF
sasl.mechanism=PLAIN
security.protocol=SASL_PLAINTEXT
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="admin" password="admin123";
EOF

# Create topic
docker exec kafka-broker kafka-topics \
  --bootstrap-server localhost:9093 \
  --command-config /tmp/admin.properties \
  --create \
  --topic db.postgres.users \
  --partitions 3 \
  --replication-factor 1
```

### Test Producer (as Debezium)

```bash
# Create debezium properties file
cat > debezium.properties <<EOF
sasl.mechanism=PLAIN
security.protocol=SASL_PLAINTEXT
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="debezium" password="debezium-pass-123";
EOF

# Produce messages
docker exec -i kafka-broker kafka-console-producer \
  --bootstrap-server localhost:9093 \
  --topic db.postgres.users \
  --producer.config /tmp/debezium.properties <<EOF
{"id":1,"name":"John"}
{"id":2,"name":"Jane"}
EOF
```

### Test Consumer

```bash
# Consume messages
docker exec kafka-broker kafka-console-consumer \
  --bootstrap-server localhost:9093 \
  --topic db.postgres.users \
  --from-beginning \
  --consumer.config /tmp/admin.properties
```

## Troubleshooting

### Oracle ARCHIVELOG not enabled

```bash
# Check current mode
docker compose exec oracle sqlplus -s / as sysdba <<EOF
SELECT LOG_MODE FROM V\$DATABASE;
EXIT;
EOF

# If shows NOARCHIVELOG, restart Oracle
docker compose restart oracle

# Monitor startup script
docker compose logs -f oracle | grep -i archivelog
```

### Connector stuck in FAILED state

```bash
# Check connector logs
docker compose logs debezium-connect | grep -i error

# Delete and redeploy connector
docker compose exec debezium-connect curl -X DELETE http://localhost:8083/connectors/oracle-cdc-connector
docker compose restart debezium-oracle-source-setup

# Check status again
docker compose exec debezium-connect curl -s http://localhost:8083/connectors/oracle-cdc-connector/status | jq
```

### ORA-01031: insufficient privileges

```bash
# Verify C##DBZUSER privileges
docker compose exec oracle sqlplus -s / as sysdba <<EOF
SELECT grantee, privilege FROM dba_sys_privs WHERE grantee = 'C##DBZUSER' ORDER BY privilege;
EXIT;
EOF

# Should see: CREATE SESSION, FLASHBACK ANY TABLE, LOCK ANY TABLE, CREATE TABLE, etc.
```

### Kafka authentication failures

```bash
# Check SCRAM users
docker compose exec kafka-broker kafka-configs \
  --bootstrap-server localhost:9093 \
  --command-config /tmp/admin.properties \
  --describe \
  --entity-type users

# Verify debezium user exists
# Should see: debezium user with SCRAM-SHA-256
```

### Type mismatch errors in sink

```bash
# Check sink connector error
docker compose logs debezium-connect | grep -i "type mismatch\|cast"

# Verify schema compatibility in database
docker compose exec postgres psql -U postgres -d cdcdb -c "\d users"
docker compose exec oracle sqlplus APPUSER/appuser123@//localhost:1521/CDCDB <<EOF
DESC USERS;
EXIT;
EOF
```

### Clean restart

```bash
# Nuclear option: reset everything
docker compose down -v
rm -rf docker-vol/*
docker compose up -d

# Wait 2-3 minutes for all services
docker compose ps
docker compose logs -f
```

## Project Structure

```
debezium-cdc-postgres-oracle/
├── docker-compose.yml                    # Main orchestration
├── .env                                  # Environment config (git-ignored)
├── .env-example                          # Environment template
├── .gitignore                            # Git ignore rules
├── README.md                             # Documentation
├── config/
│   ├── kafka_jaas.conf                  # SASL SCRAM authentication
│   ├── oracle/
│   │   ├── init.sql                     # Oracle schema + CDC user setup
│   │   └── startup/
│   │       └── enable-archivelog.sh     # ARCHIVELOG enablement script
│   ├── postgres/
│   │   └── init.sql                     # PostgreSQL schema + replication
│   └── debezium/
│       ├── oracle-source-connector.json # Oracle CDC source config
│       ├── postgres-sink-connector.json # PostgreSQL sink config
│       ├── postgres-source-connector.json # (for Postgres mode)
│       └── oracle-sink-connector.json   # (for Postgres mode)
├── scripts/
│   ├── format-kafka.sh                  # KRaft storage formatter
│   ├── setup-acls.sh                    # Kafka ACL configuration
│   ├── setup-debezium-oracle-source.sh  # Deploy Oracle CDC connector
│   ├── setup-debezium-postgres-sink.sh  # Deploy Postgres sink
│   └── (other setup scripts)
└── docker-vol/                          # Persistent data (git-ignored)
    ├── kafka-data/
    ├── oracle-data/
    └── postgres-data/
```

## Oracle CDC Architecture Details

### LogMiner Configuration
- **Strategy**: `online_catalog` (no dictionary extraction)
- **Continuous Mine**: `false` (Oracle XE 21c limitation)
- **Supplemental Logging**: Enabled at CDB and table level
- **ARCHIVELOG Mode**: Auto-enabled via startup script

### C##DBZUSER Privileges
Required for LogMiner CDC:
- `CREATE SESSION`, `SET CONTAINER`
- `SELECT ANY TABLE`, `FLASHBACK ANY TABLE`, `LOCK ANY TABLE`
- `CREATE TABLE`, `ALTER ANY TABLE`, `DROP ANY TABLE` (for flush tables)
- `SELECT ANY TRANSACTION`, `LOGMINING`
- `EXECUTE` on `DBMS_LOGMNR`, `DBMS_LOGMNR_D`
- Access to `V$` views: `V$DATABASE`, `V$LOG`, `V$LOGFILE`, `V$ARCHIVED_LOG`, etc.

All grants include `CONTAINER=ALL` for PDB access.

## Key Implementation Notes

### Why BIGSERIAL instead of SERIAL?
Oracle `NUMBER` has no size limit, while Postgres `INTEGER` max is ~2.1B. Using `BIGSERIAL` (max 9.2 quintillion) ensures compatibility for all use cases.

### Why VARCHAR(45) for IP address?
Originally used Postgres `INET` type, but Oracle has `VARCHAR2` only. Changed to `VARCHAR(45)` (supports IPv6 length) for bi-directional compatibility.

### Why no CONTINUOUS_MINE?
Oracle XE 21c doesn't support `DBMS_LOGMNR.CONTINUOUS_MINE` option. Using batch mode with `log.mining.continuous.mine=false` instead.

## Services & Ports

| Service | Port | Description |
|---------|------|-------------|
| Kafka Broker | 9093 | SASL_PLAINTEXT (SCRAM-SHA-256) |
| Kafka UI | 8080 | Web interface |
| Debezium Connect | 8083 | REST API |
| PostgreSQL | 5432 | Database |
| Oracle XE | 1521 | Database (TNS) |

## Production Recommendations

For production deployment, consider:
- Enable TLS: Use `SASL_SSL` instead of `SASL_PLAINTEXT`
- Multi-broker Kafka cluster for high availability
- Dedicated Oracle Standard or Enterprise Edition (not XE)
- External secrets management (Vault, AWS Secrets Manager)
- Monitoring: Prometheus and Grafana for metrics
- Backup strategy for Kafka offsets and database snapshots

## License

MIT License - Free for personal and commercial use.

---

**Status**: Production-ready unidirectional CDC system

**Last Updated**: October 2025

**Tested With**: 
- Oracle XE 21.3.0.0.0
- PostgreSQL 16
- Debezium 2.5
- Kafka 3.6.1
