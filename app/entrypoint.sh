#!/bin/bash
# entrypoint: waits for oracle, runs sql setup, starts gunicorn

echo "Waiting for Oracle DB to be ready..."

MAX_RETRIES=60
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do

    # try connecting to oracle
    python -c "
import oracledb, os, sys
try:
    conn = oracledb.connect(
        user=os.environ.get('DB_USER', 'system'),
        password=os.environ.get('DB_PASS', 'password123'),
        dsn=os.environ.get('DB_DSN', 'oracle-xe:1521/XE')
    )
    conn.close()
    sys.exit(0)
except Exception as e:
    print(f'Connection error: {e}', file=sys.stderr)
    sys.exit(1)
"

    if [ $? -eq 0 ]; then
        echo "Oracle DB is ready!"

        # run sql setup only on first boot
        if [ ! -f /tmp/.db_initialized ]; then
            echo "Running database setup (00_full_setup.sql)..."
            python <<'PYEOF'
import oracledb, os, re

conn = oracledb.connect(
    user=os.environ.get('DB_USER', 'system'),
    password=os.environ.get('DB_PASS', 'password123'),
    dsn=os.environ.get('DB_DSN', 'oracle-xe:1521/XE')
)
cursor = conn.cursor()

with open('/sql/00_full_setup.sql', 'r') as f:
    sql_content = f.read()

# strip sqlplus-only commands but keep SQL SET clauses
sqlplus_cmds = ('SET SERVEROUTPUT', 'SET LINESIZE', 'SET PAGESIZE',
                'SET TRIMSPOOL', 'SET FEEDBACK', 'SET ECHO',
                'SET VERIFY', 'SET DEFINE', 'SET TIMING')
lines = []
for l in sql_content.split('\n'):
    stripped = l.strip().upper()
    if any(stripped.startswith(cmd) for cmd in sqlplus_cmds):
        continue
    lines.append(l)
sql_content = '\n'.join(lines)

# split into statements
# plsql blocks end with '/' on its own line, regular ddl ends with ';'
statements = []
current = []
in_plsql = False

for line in sql_content.split('\n'):
    stripped = line.strip()

    if not current and (not stripped or stripped.startswith('--')):
        continue

    if not in_plsql and not current:
        upper = stripped.upper()
        if (upper.startswith('CREATE OR REPLACE') or
            upper.startswith('CREATE TRIGGER') or
            upper.startswith('BEGIN') or
            upper.startswith('DECLARE')):
            in_plsql = True

    # '/' alone ends a plsql block
    if stripped == '/' and in_plsql:
        stmt = '\n'.join(current).strip()
        if stmt:
            statements.append(stmt)
        current = []
        in_plsql = False
        continue

    current.append(line)

    if not in_plsql and stripped.endswith(';'):
        stmt = '\n'.join(current).strip()
        stmt = stmt.rstrip(';').strip()
        if stmt and not stmt.startswith('--'):
            statements.append(stmt)
        current = []

if current:
    stmt = '\n'.join(current).strip().rstrip(';').strip()
    if stmt and not stmt.startswith('--'):
        statements.append(stmt)

ok = 0
errors = 0
for i, stmt in enumerate(statements):
    try:
        cursor.execute(stmt)
        conn.commit()
        ok += 1
    except Exception as e:
        err = str(e)
        # ignore "already exists" / "does not exist" errors
        if 'ORA-00955' in err or 'ORA-04043' in err or 'ORA-00942' in err or 'ORA-01430' in err:
            pass
        else:
            print(f'SQL Error (stmt {i}): {err[:200]}')
            errors += 1
        conn.rollback()

cursor.close()
conn.close()
print(f'Database setup completed! ({ok} executed, {errors} errors)')
PYEOF
            touch /tmp/.db_initialized
        else
            echo "Database already initialized, skipping setup."
        fi

        # start gunicorn
        echo "Starting Flask application on port 5000..."
        exec gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
    fi

    RETRY=$((RETRY + 1))
    echo "Oracle not ready yet (attempt $RETRY/$MAX_RETRIES)... retrying in 5s"
    sleep 5
done

echo "ERROR: Oracle DB did not become ready after $MAX_RETRIES attempts"
exit 1
