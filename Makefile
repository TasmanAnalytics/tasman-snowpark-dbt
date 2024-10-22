export DBT_PROFILES_DIR := ~/.dbt/
.PHONY: help

###############
## Variables ##
###############

SNOWFLAKE_REGISTRY := xxxxx-xxxxx.registry.snowflakecomputing.com # add your snowflake registry here
SNOWFLAKE_USER := YOUR_SNOWFLAKE_USER # add your Snowflake user name here
SNOWFLAKE_CLI_CONNECTION_NAME := tasman

SNOWFLAKE_DBT_ROLE := DBT_SNOWPARK_ROLE
SNOWFLAKE_DBT_DATABASE := DBT_SNOWPARK_DB
SNOWFLAKE_DBT_SCHEMA := JAFFLE_SHOP_SNOWPARK
SNOWFLAKE_DBT_COMPUTE_POOL := DBT_SNOWPARK_COMPUTE_POOL
SNOWFLAKE_DBT_JOB_NAME := DBT_SNOWPARK_JOB

SNOWFLAKE_CLI_JOB_SPEC_FILE_PATH := snowpark_dbt_spec.yaml

DOCKER_DBT_SNOWPARK_IMAGE_NAME := dbt-snowpark

####################
## dbt local runs ##
####################

venv-create:	## Create venv
	python3 -m venv venv

venv-activate: venv-create	## Activate venv
	. venv/bin/activate

install-dbt-snowflake: venv-activate	## Install dbt-snowflake package (pre-release version) 
	pip install git+https://github.com/dbt-labs/dbt-snowflake.git@v1.9.0b1

run-dbt-deps: install-dbt-snowflake	## Install dbt dependencies 
	cd jaffle-shop && dbt deps

run-dbt-build-local: run-dbt-deps	## Run dbt build with local profile 
	cd jaffle-shop && dbt build --target local


#####################
## Docker commands ##
#####################

docker-login-sf:	## Docker Login to Snowflake Registry 
	docker login $(SNOWFLAKE_REGISTRY) -u $(SNOWFLAKE_USER)

docker-dbt-snowpark-build:	## Build dbt-snowpark image
	docker buildx build -t $(DOCKER_DBT_SNOWPARK_IMAGE_NAME) .

docker-dbt-snowpark-build-tag-push-sf: docker-dbt-snowpark-build	## Tags and pushes the dbt-snowpark image to Snowflake Registry
	docker tag $(DOCKER_DBT_SNOWPARK_IMAGE_NAME) $(SNOWFLAKE_REGISTRY)/$(SNOWFLAKE_DBT_DATABASE)/$(SNOWFLAKE_DBT_SCHEMA)/image_repository/$(DOCKER_DBT_SNOWPARK_IMAGE_NAME)
	docker push $(SNOWFLAKE_REGISTRY)/$(SNOWFLAKE_DBT_DATABASE)/$(SNOWFLAKE_DBT_SCHEMA)/image_repository/$(DOCKER_DBT_SNOWPARK_IMAGE_NAME)


############################
## Snowflake CLI Commands ##
############################

sf-cli-execute-dbt-job-service:
	snow spcs service execute-job \
		$(SNOWFLAKE_DBT_DATABASE).$(SNOWFLAKE_DBT_SCHEMA).$(SNOWFLAKE_DBT_JOB_NAME) \
		--spec-path $(SNOWFLAKE_CLI_JOB_SPEC_FILE_PATH) \
		--compute-pool $(SNOWFLAKE_DBT_COMPUTE_POOL) \
		--role $(SNOWFLAKE_DBT_ROLE) \
		--connection $(SNOWFLAKE_CLI_CONNECTION_NAME)

sf-cli-drop-dbt-job-service:
	snow spcs service drop \
		$(SNOWFLAKE_DBT_DATABASE).$(SNOWFLAKE_DBT_SCHEMA).$(SNOWFLAKE_DBT_JOB_NAME) \
		--role $(SNOWFLAKE_DBT_ROLE) \
		--connection $(SNOWFLAKE_CLI_CONNECTION_NAME)


##########
## Misc ##
##########

help:	## Show targets and comments (must have ##)
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'