# All-in-one image: Oracle XE 21c + ConferenceHub Flask app
# Usage: docker run -p 5000:5000 ghcr.io/icekern/db:latest
# First startup takes ~2 min (Oracle init + schema setup)

FROM gvenzl/oracle-xe:21-slim

USER root

# install python 3.9
RUN microdnf install -y python39 && \
    microdnf clean all

# install python dependencies
COPY app/requirements.txt /tmp/requirements.txt
RUN python3.9 -m pip install --no-cache-dir -r /tmp/requirements.txt

# copy flask app
COPY app/ /app/
RUN rm -f /app/entrypoint.sh /app/setup.bat /app/start_server.bat /app/.dockerignore

# copy sql init script (gvenzl/oracle-xe auto-runs scripts in this dir)
COPY sql/00_full_setup.sql /container-entrypoint-initdb.d/

# copy wrapper entrypoint
COPY standalone-entrypoint.sh /standalone-entrypoint.sh
RUN chmod +x /standalone-entrypoint.sh

USER oracle

EXPOSE 1521 5000

# default oracle password (override with -e ORACLE_PASSWORD=...)
ENV ORACLE_PASSWORD=password123

ENTRYPOINT ["/standalone-entrypoint.sh"]
