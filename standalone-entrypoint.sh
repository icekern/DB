#!/bin/bash
# all-in-one entrypoint: starts Oracle in background, waits for schema init, then starts Flask

# start Oracle's official entrypoint in background
# it handles: starting Oracle, running init scripts from /container-entrypoint-initdb.d/, then tailing alert log
/container-entrypoint.sh &

echo "==> Waiting for Oracle Database + schema setup..."
echo "==> First run takes ~2 minutes, subsequent runs are faster."

MAX_WAIT=300
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if python3.9 -c "
import oracledb
conn = oracledb.connect(user='system', password='${ORACLE_PASSWORD}', dsn='localhost:1521/XE')
cur = conn.cursor()
cur.execute('SELECT COUNT(*) FROM Conference')
count = cur.fetchone()[0]
cur.close()
conn.close()
if count == 0:
    raise Exception('no data yet')
" 2>/dev/null; then
        echo "==> Database ready!"
        break
    fi

    sleep 5
    WAITED=$((WAITED + 5))
    echo "    waiting... (${WAITED}s)"
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "ERROR: Database did not become ready in ${MAX_WAIT}s"
    exit 1
fi

echo "==> Starting ConferenceHub on http://localhost:5000"

cd /app
export DB_USER=system
export DB_PASS="${ORACLE_PASSWORD}"
export DB_DSN=localhost:1521/XE
export SECRET_KEY="${SECRET_KEY:-conferencehub_standalone}"

exec python3.9 -m gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
