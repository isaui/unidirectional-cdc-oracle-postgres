#!/usr/bin/env python3
"""
Unified Data Producer for CDC Testing
Supports both PostgreSQL and Oracle based on CDC_MODE environment variable
"""

import os
import sys
import time
import random
import argparse
from datetime import datetime

# Read CDC mode from environment
CDC_MODE = os.getenv('CDC_MODE', 'POSTGRES').upper()

# Import appropriate database library based on mode
if CDC_MODE == 'POSTGRES':
    import psycopg2
elif CDC_MODE == 'ORACLE':
    import oracledb
else:
    print(f"[ERROR] Invalid CDC_MODE: {CDC_MODE}. Must be 'POSTGRES' or 'ORACLE'")
    sys.exit(1)

# Database configuration
if CDC_MODE == 'POSTGRES':
    DB_CONFIG = {
        'host': os.getenv('DB_HOST', 'postgres'),
        'port': os.getenv('DB_PORT', '5432'),
        'database': os.getenv('POSTGRES_DB', 'cdcdb'),
        'user': os.getenv('POSTGRES_USER', 'postgres'),
        'password': os.getenv('POSTGRES_PASSWORD', 'postgres123')
    }
else:  # ORACLE
    DB_CONFIG = {
        'host': os.getenv('ORACLE_HOST', 'oracle'),
        'port': int(os.getenv('ORACLE_PORT', '1521')),
        'service_name': os.getenv('ORACLE_DATABASE', 'CDCDB'),
        'user': os.getenv('ORACLE_APP_USER', 'appuser'),
        'password': os.getenv('ORACLE_APP_PASSWORD', 'appuser123')
    }

# Sample data
USERNAMES = ['alice', 'bob', 'charlie', 'diana', 'eve', 'frank', 'grace', 'henry', 'iris', 'jack']
DOMAINS = ['example.com', 'test.com', 'demo.com', 'sample.org']
STATUSES = ['active', 'inactive', 'suspended']
ACTIVITY_TYPES = ['login', 'logout', 'profile_update', 'password_change', 
                  'purchase', 'view_product', 'add_to_cart', 'checkout']


def create_connection():
    """Create database connection based on CDC_MODE"""
    if CDC_MODE == 'POSTGRES':
        return create_postgres_connection()
    else:
        return create_oracle_connection()


def create_postgres_connection():
    """Create PostgreSQL connection with retry logic"""
    max_retries = 30
    retry_delay = 5
    
    for attempt in range(1, max_retries + 1):
        try:
            print(f"[INFO] Connecting to PostgreSQL... (Attempt {attempt}/{max_retries})")
            conn = psycopg2.connect(
                host=DB_CONFIG['host'],
                port=DB_CONFIG['port'],
                database=DB_CONFIG['database'],
                user=DB_CONFIG['user'],
                password=DB_CONFIG['password'],
                connect_timeout=10
            )
            print(f"[SUCCESS] Connected to PostgreSQL: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
            return conn
        except Exception as e:
            print(f"[ERROR] Failed to connect: {e}")
            if attempt < max_retries:
                print(f"[INFO] Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                print(f"[FATAL] Max retries reached. Exiting.")
                sys.exit(1)


def create_oracle_connection():
    """Create Oracle connection with retry logic"""
    max_retries = 30
    retry_delay = 5
    
    for attempt in range(1, max_retries + 1):
        try:
            print(f"[INFO] Connecting to Oracle... (Attempt {attempt}/{max_retries})")
            conn = oracledb.connect(
                user=DB_CONFIG['user'],
                password=DB_CONFIG['password'],
                host=DB_CONFIG['host'],
                port=DB_CONFIG['port'],
                service_name=DB_CONFIG['service_name']
            )
            print(f"[SUCCESS] Connected to Oracle: {DB_CONFIG['user']}@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['service_name']}")
            return conn
        except Exception as e:
            print(f"[ERROR] Failed to connect: {e}")
            if attempt < max_retries:
                print(f"[INFO] Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                print(f"[FATAL] Max retries reached. Exiting.")
                sys.exit(1)


def insert_user_postgres(cursor):
    """Insert user into PostgreSQL"""
    username = f"{random.choice(USERNAMES)}_{random.randint(1000, 9999)}"
    email = f"{username}@{random.choice(DOMAINS)}"
    full_name = f"{random.choice(['John', 'Jane', 'Bob', 'Alice'])} {random.choice(['Doe', 'Smith', 'Johnson'])}"
    status = random.choice(STATUSES)
    
    try:
        cursor.execute("""
            INSERT INTO users (username, email, full_name, status)
            VALUES (%s, %s, %s, %s)
            RETURNING id
        """, (username, email, full_name, status))
        
        user_id = cursor.fetchone()[0]
        return user_id, username, status
    except Exception as e:
        if 'duplicate key' in str(e):
            return None, None, None
        raise


def insert_user_oracle(cursor):
    """Insert user into Oracle"""
    username = f"{random.choice(USERNAMES)}_{random.randint(1000, 9999)}"
    email = f"{username}@{random.choice(DOMAINS)}"
    full_name = f"{random.choice(['John', 'Jane', 'Bob', 'Alice'])} {random.choice(['Doe', 'Smith', 'Johnson'])}"
    status = random.choice(STATUSES)
    
    try:
        cursor.execute("""
            INSERT INTO USERS (USERNAME, EMAIL, FULL_NAME, STATUS)
            VALUES (:1, :2, :3, :4)
            RETURNING ID INTO :5
        """, [username, email, full_name, status, cursor.var(int)])
        
        user_id = cursor.getvar(4).getvalue()[0]
        return user_id, username, status
    except Exception as e:
        return None, None, None


def update_user_postgres(cursor):
    """Update random user in PostgreSQL"""
    try:
        cursor.execute("SELECT id, username FROM users ORDER BY RANDOM() LIMIT 1")
        result = cursor.fetchone()
        
        if result:
            user_id, username = result
            new_status = random.choice(STATUSES)
            cursor.execute("""
                UPDATE users 
                SET status = %s, updated_at = CURRENT_TIMESTAMP 
                WHERE id = %s
            """, (new_status, user_id))
            return user_id, username, new_status
    except Exception:
        pass
    return None, None, None


def update_user_oracle(cursor):
    """Update random user in Oracle"""
    try:
        cursor.execute("SELECT ID, USERNAME FROM USERS WHERE ROWNUM = 1 ORDER BY DBMS_RANDOM.VALUE")
        result = cursor.fetchone()
        
        if result:
            user_id, username = result
            new_status = random.choice(STATUSES)
            cursor.execute("""
                UPDATE USERS 
                SET STATUS = :1, UPDATED_AT = CURRENT_TIMESTAMP
                WHERE ID = :2
            """, [new_status, user_id])
            return user_id, username, new_status
    except Exception:
        pass
    return None, None, None


def insert_activity_postgres(cursor):
    """Insert activity into PostgreSQL"""
    try:
        cursor.execute("SELECT id FROM users ORDER BY RANDOM() LIMIT 1")
        result = cursor.fetchone()
        
        if not result:
            return None, None, None
        
        user_id = result[0]
        activity_type = random.choice(ACTIVITY_TYPES)
        description = f"User performed {activity_type}"
        ip_address = f"{random.randint(10, 192)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}"
        user_agent = f"Mozilla/5.0 Test/{random.randint(1,100)}"
        
        cursor.execute("""
            INSERT INTO user_activities (user_id, activity_type, description, ip_address, user_agent)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
        """, (user_id, activity_type, description, ip_address, user_agent))
        
        activity_id = cursor.fetchone()[0]
        return activity_id, user_id, activity_type
    except Exception:
        return None, None, None


def insert_activity_oracle(cursor):
    """Insert activity into Oracle"""
    try:
        cursor.execute("SELECT ID FROM USERS WHERE ROWNUM = 1 ORDER BY DBMS_RANDOM.VALUE")
        result = cursor.fetchone()
        
        if not result:
            return None, None, None
        
        user_id = result[0]
        activity_type = random.choice(ACTIVITY_TYPES)
        description = f"User performed {activity_type}"
        ip_address = f"192.168.{random.randint(1,255)}.{random.randint(1,255)}"
        user_agent = f"Mozilla/5.0 Test/{random.randint(1,100)}"
        
        cursor.execute("""
            INSERT INTO USER_ACTIVITIES (USER_ID, ACTIVITY_TYPE, DESCRIPTION, IP_ADDRESS, USER_AGENT)
            VALUES (:1, :2, :3, :4, :5)
            RETURNING ID INTO :6
        """, [user_id, activity_type, description, ip_address, user_agent, cursor.var(int)])
        
        activity_id = cursor.getvar(5).getvalue()[0]
        return activity_id, user_id, activity_type
    except Exception:
        return None, None, None


def generate_data(conn, interval=3):
    """Continuously generate data"""
    print(f"[INFO] Starting data producer in {CDC_MODE} mode...")
    print(f"[INFO] Interval: {interval}s")
    print(f"[INFO] Press Ctrl+C to stop")
    print("-" * 60)
    
    operation_count = 0
    cursor = conn.cursor()
    
    try:
        while True:
            # Randomly choose operation
            operation = random.choices(
                ['insert_user', 'update_user', 'insert_activity'],
                weights=[2, 1, 5]  # More activities than users
            )[0]
            
            try:
                if operation == 'insert_user':
                    if CDC_MODE == 'POSTGRES':
                        user_id, username, status = insert_user_postgres(cursor)
                    else:
                        user_id, username, status = insert_user_oracle(cursor)
                    
                    if user_id:
                        conn.commit()
                        operation_count += 1
                        print(f"[{operation_count}] [INSERT USER] ID:{user_id} {username} ({status})")
                
                elif operation == 'update_user':
                    if CDC_MODE == 'POSTGRES':
                        user_id, username, new_status = update_user_postgres(cursor)
                    else:
                        user_id, username, new_status = update_user_oracle(cursor)
                    
                    if user_id:
                        conn.commit()
                        operation_count += 1
                        print(f"[{operation_count}] [UPDATE USER] ID:{user_id} {username} -> {new_status}")
                
                elif operation == 'insert_activity':
                    if CDC_MODE == 'POSTGRES':
                        activity_id, user_id, activity_type = insert_activity_postgres(cursor)
                    else:
                        activity_id, user_id, activity_type = insert_activity_oracle(cursor)
                    
                    if activity_id:
                        conn.commit()
                        operation_count += 1
                        print(f"[{operation_count}] [INSERT ACTIVITY] ID:{activity_id} User:{user_id} Type:{activity_type}")
                
            except Exception as e:
                print(f"[ERROR] Operation failed: {e}")
                conn.rollback()
            
            time.sleep(interval)
    
    except KeyboardInterrupt:
        print("\n[INFO] Stopping data producer...")
    finally:
        cursor.close()
        print(f"[INFO] Total operations: {operation_count}")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Unified Data Producer for CDC Testing')
    parser.add_argument('--interval', type=float, default=3.0, help='Interval between operations (seconds)')
    
    args = parser.parse_args()
    
    print("=" * 60)
    print(f"Unified Data Producer - Mode: {CDC_MODE}")
    print("=" * 60)
    
    conn = create_connection()
    generate_data(conn, interval=args.interval)
    conn.close()


if __name__ == '__main__':
    main()
