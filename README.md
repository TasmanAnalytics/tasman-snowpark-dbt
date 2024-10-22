# tasman-snowpark-dbt
This repository contains all the code and resources used in Tasman's article [Running dbt in Snowpark](https://blog.tasman.ai).

## Contents
- [dbt generic repository (jaffle-shop) containing some seeds and models](jaffle-shop)
- [Python entrypoint file customised to work with Snowpark](jaffle-shop/entrypoint.py)
- [Dockerfile to create a Docker image for Snowpark](Dockerfile)
- [Snowflake script used to create all resources](snowpark.sql)
- [Makefile to help setting up local environment, building and pushing the Docker image, and running jobs in Snowflake CLI](Makefile)

