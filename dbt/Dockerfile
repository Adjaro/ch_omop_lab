FROM python:3.12-slim

# Index pip configurable (miroir interne / proxy d'entreprise) : --build-arg PIP_INDEX_URL=...
ARG PIP_INDEX_URL=https://pypi.org/simple
ENV PIP_INDEX_URL=${PIP_INDEX_URL} \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Versions validées ensemble sur ce projet
RUN pip install dbt-core==1.12.6 dbt-clickhouse==1.10.3

WORKDIR /dbt
ENTRYPOINT ["dbt"]
CMD ["build"]
