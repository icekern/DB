# dockerfile for the flask app, runs with gunicorn
# build context must be the project root (not ./app)
FROM python:3.12-slim

WORKDIR /app

# install python dependencies
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# copy application code
COPY app/ .

# copy sql scripts into the image so the entrypoint can init the db
COPY sql/ /sql/

# fix windows line endings and make entrypoint executable
RUN sed -i 's/\r$//' entrypoint.sh && chmod +x entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]
