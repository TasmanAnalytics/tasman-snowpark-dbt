FROM python:3.11-slim-buster

ENV DBT_PROJECT_DIR=/usr/dbt
ENV DBT_PROFILES_DIR=$DBT_PROJECT_DIR
ENV DBT_PROJECT_DIR_NAME=jaffle-shop
ENV PATH="/usr/.venv/bin:$PATH"

WORKDIR /usr

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY ${DBT_PROJECT_DIR_NAME} ${DBT_PROJECT_DIR}

WORKDIR ${DBT_PROJECT_DIR}

RUN dbt deps

ENTRYPOINT ["python", "/usr/dbt/entrypoint.py" ]
