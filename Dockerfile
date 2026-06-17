FROM bitnami/spark:3.5

# Build args — keep in sync with the bitnami/spark:3.5 version
ARG SPARK_VERSION=3.5.1
ARG SCALA_VERSION=2.12

USER root

# ─── Extra JARs (Kafka, PostgreSQL, Delta Lake) ───────────────────────────────
# Placed in SPARK_HOME/jars so they are on the classpath automatically.
RUN JAR_DIR=/opt/bitnami/spark/jars \
 && BASE=https://repo1.maven.org/maven2 \
 # Kafka integration
 && curl -fsSL "${BASE}/org/apache/spark/spark-sql-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar" \
         -o "${JAR_DIR}/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar" \
 && curl -fsSL "${BASE}/org/apache/spark/spark-token-provider-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-token-provider-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar" \
         -o "${JAR_DIR}/spark-token-provider-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar" \
 && curl -fsSL "${BASE}/org/apache/kafka/kafka-clients/3.4.1/kafka-clients-3.4.1.jar" \
         -o "${JAR_DIR}/kafka-clients-3.4.1.jar" \
 && curl -fsSL "${BASE}/org/apache/commons/commons-pool2/2.11.1/commons-pool2-2.11.1.jar" \
         -o "${JAR_DIR}/commons-pool2-2.11.1.jar" \
 # PostgreSQL JDBC
 && curl -fsSL "${BASE}/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar" \
         -o "${JAR_DIR}/postgresql-42.7.3.jar" \
 # Delta Lake (compatible with Spark 3.5.x)
 && curl -fsSL "${BASE}/io/delta/delta-spark_${SCALA_VERSION}/3.2.0/delta-spark_${SCALA_VERSION}-3.2.0.jar" \
         -o "${JAR_DIR}/delta-spark_${SCALA_VERSION}-3.2.0.jar" \
 && curl -fsSL "${BASE}/io/delta/delta-storage/3.2.0/delta-storage-3.2.0.jar" \
         -o "${JAR_DIR}/delta-storage-3.2.0.jar"

# ─── Python packages ──────────────────────────────────────────────────────────
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# ─── Jupyter home ─────────────────────────────────────────────────────────────
RUN mkdir -p /home/jupyter/notebooks /home/jupyter/data \
 && chown -R 1001:1001 /home/jupyter

USER 1001
WORKDIR /home/jupyter

EXPOSE 8888 4040

CMD jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --notebook-dir=/home/jupyter/notebooks \
    "--ServerApp.token=${JUPYTER_TOKEN:-spark123}"
