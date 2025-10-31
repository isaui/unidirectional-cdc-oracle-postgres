#!/bin/bash
set -e

echo "=================================================="
echo "Checking ARCHIVELOG mode..."
echo "=================================================="

# Check if archivelog is already enabled
ARCHIVELOG_STATUS=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF
SET PAGESIZE 0
SELECT LOG_MODE FROM V\$DATABASE;
EXIT;
EOF
)

if echo "$ARCHIVELOG_STATUS" | grep -qw "ARCHIVELOG"; then
    echo "✅ ARCHIVELOG mode already enabled"
    exit 0
fi

echo "⚠️  ARCHIVELOG mode not enabled. Enabling now..."

# Enable archivelog mode
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET db_recovery_file_dest_size = 10G;
ALTER SYSTEM SET db_recovery_file_dest = '/opt/oracle/oradata' scope=spfile;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ARCHIVE LOG LIST;
EXIT;
EOF

echo "✅ ARCHIVELOG mode enabled successfully!"
echo "=================================================="
