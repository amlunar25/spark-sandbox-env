# ── Stage 1: shared base — Spark 4.0.3 + all extra JARs ─────────────────────
# Both the cluster nodes and the notebook container build from this stage,
# so every executor node already has the same JARs as the driver.
FROM apache/spark:4.0.3-python3 AS spark-base

ARG SPARK_VERSION=4.0.3
ARG SCALA_VERSION=2.13

USER root

# Wire PySpark (bundled at /opt/spark/python) without a conflicting pip install
ENV PYTHONPATH=/opt/spark/python:/opt/spark/python/lib/py4j-0.10.9.9-src.zip
ENV PYSPARK_PYTHON=python3

RUN JAR_DIR=/opt/spark/jars \
 && BASE=https://repo1.maven.org/maven2 \
 # Kafka integration (Scala 2.13 artifacts for Spark 4.x)
 && curl -fsSL "${BASE}/org/apache/spark/spark-sql-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar" \
         -o "${JAR_DIR}/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar" \
 && curl -fsSL "${BASE}/org/apache/spark/spark-token-provider-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-token-provider-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar" \
         -o "${JAR_DIR}/spark-token-provider-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar" \
 && curl -fsSL "${BASE}/org/apache/kafka/kafka-clients/3.9.1/kafka-clients-3.9.1.jar" \
         -o "${JAR_DIR}/kafka-clients-3.9.1.jar" \
 && curl -fsSL "${BASE}/org/apache/commons/commons-pool2/2.12.0/commons-pool2-2.12.0.jar" \
         -o "${JAR_DIR}/commons-pool2-2.12.0.jar" \
 # PostgreSQL JDBC
 && curl -fsSL "${BASE}/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar" \
         -o "${JAR_DIR}/postgresql-42.7.3.jar" \
 # Delta Lake 4.x (Spark 4.x / Scala 2.13)
 && curl -fsSL "${BASE}/io/delta/delta-spark_${SCALA_VERSION}/4.0.0/delta-spark_${SCALA_VERSION}-4.0.0.jar" \
         -o "${JAR_DIR}/delta-spark_${SCALA_VERSION}-4.0.0.jar" \
 && curl -fsSL "${BASE}/io/delta/delta-storage/4.0.0/delta-storage-4.0.0.jar" \
         -o "${JAR_DIR}/delta-storage-4.0.0.jar"

# Conf dir for the spark-defaults.conf bind-mount
RUN mkdir -p /opt/spark/conf


# ── Stage 2: cluster node (spark-master + spark-worker) ──────────────────────
FROM spark-base AS cluster
USER 185


# ── Stage 3: notebook (spark-base + JupyterLab + Python packages) ─────────────
FROM spark-base AS notebook

COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --upgrade pip --quiet \
 && pip3 install --no-cache-dir -r /tmp/requirements.txt

RUN mkdir -p /home/jupyter/notebooks /home/jupyter/data \
 && useradd -m -u 1000 -d /home/jupyter -s /bin/bash jupyter \
 && chown -R 1000:1000 /home/jupyter

USER 1000
WORKDIR /home/jupyter

EXPOSE 8888 4040

# Override the K8s-oriented entrypoint from the base image
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --notebook-dir=/home/jupyter/notebooks --ServerApp.token=${JUPYTER_TOKEN:-spark123}"]
