---------------------
-- Create database --
---------------------
use role SYSADMIN ;
create database DBT_SNOWPARK_DB ;

-- Schemas
use database DBT_SNOWPARK_DB ;

create schema JAFFLE_SHOP_LOCAL ; -- for local dbt runs
create schema JAFFLE_SHOP_SNOWPARK ; -- for Snowpark dbt runs
create schema RAW ; -- will be useful for storing raw data

----------------------
-- Create warehouse --
----------------------
use role SYSADMIN ;
create or replace warehouse DBT_SNOWPARK_WH
    warehouse_size = 'XSMALL'
    auto_suspend = 60 
;

-----------------
-- Create Role --
-----------------

use role SECURITYADMIN;
create role DBT_SNOWPARK_ROLE ;
grant role DBT_SNOWPARK_ROLE to role SYSADMIN ; -- good practice


-- Role Grants on Database 
grant usage on database DBT_SNOWPARK_DB to role DBT_SNOWPARK_ROLE ;

-- Role Grants on dbt Schemas
grant all privileges on schema DBT_SNOWPARK_DB.JAFFLE_SHOP_LOCAL to role DBT_SNOWPARK_ROLE ;
grant all privileges on schema DBT_SNOWPARK_DB.JAFFLE_SHOP_SNOWPARK to role DBT_SNOWPARK_ROLE ;
grant all privileges on schema DBT_SNOWPARK_DB.RAW to role DBT_SNOWPARK_ROLE ;

-- Role Grants on Warehouse
grant usage, operate on warehouse DBT_SNOWPARK_WH to role DBT_SNOWPARK_ROLE ;


------------------------
-- Grant Role to User --
------------------------

use role SECURITYADMIN ;
grant role DBT_SNOWPARK_ROLE to user <YOUR_USER> ;


------------------------
-- Snowpark Resources --
-----------------------

-------------------------------
-- Grant Create Compute Pool --
-------------------------------

use role ACCOUNTADMIN ;
grant create compute pool on account to role DBT_SNOWPARK_ROLE;


-------------------------
-- Create Compute Pool --
-------------------------

use role DBT_SNOWPARK_ROLE ;

create compute pool if not exists DBT_SNOWPARK_COMPUTE_POOL
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = CPU_X64_XS
;

describe compute pool DBT_SNOWPARK_COMPUTE_POOL;


---------------------------
-- Create Image Registry --
---------------------------

use role DBT_SNOWPARK_ROLE ;
create image repository DBT_SNOWPARK_DB.JAFFLE_SHOP_SNOWPARK.IMAGE_REPOSITORY ;

show image repositories in schema DBT_SNOWPARK_DB.JAFFLE_SHOP_SNOWPARK ;


----------------------------------
-- Disable MFA for some minutes --
----------------------------------

use role USERADMIN ;
alter user <YOUR_USER> set MINS_TO_BYPASS_MFA = 5 ;

-- Push Image is done via Docker CLI

-- Confirm image is pushed

use role DBT_SNOWPARK_ROLE ;
select SYSTEM$REGISTRY_LIST_IMAGES('/dbt_snowpark_db/jaffle_shop_snowpark/image_repository');


--------------------------
-- Run the Snowpark Job --
--------------------------

use role DBT_SNOWPARK_ROLE ;

execute job service
  in compute pool DBT_SNOWPARK_COMPUTE_POOL
  name = 'dbt_snowpark_db.jaffle_shop_snowpark.dbt_snowpark_job'
  from specification $$
    spec:
      containers:
      - name: dbt-job
        image: xxxxx-xxxxxx.registry.snowflakecomputing.com/dbt_snowpark_db/jaffle_shop_snowpark/image_repository/dbt-snowpark
        command: [ "python", "/usr/dbt/entrypoint.py", "--command", "dbt build --target snowpark" ]
  $$
;

---------------------------------------------
-- Clean the Snowpark Job Service manually --
---------------------------------------------

use role DBT_SNOWPARK_ROLE ;
drop service if exists dbt_snowpark_db.jaffle_shop_snowpark.dbt_snowpark_job ;

show services ;

-----------------------------------
-- Inspect Containers in Service --
-----------------------------------

use role DBT_SNOWPARK_ROLE ;
show service containers in service dbt_snowpark_db.jaffle_shop_snowpark.dbt_snowpark_job ;


-----------------------------------------------
-- Inspect Snowpark local container dbt logs --
-----------------------------------------------

use role DBT_SNOWPARK_ROLE ;

with service_logs as (
    select system$get_service_logs('dbt_snowpark_db.jaffle_shop_snowpark.dbt_snowpark_job', 0, 'dbt-job', 100) as logs
)
    select value as log
    from service_logs , lateral split_to_table(logs, '\n')
;

---------------------
-- Persistent Logs --
---------------------

use role ACCOUNTADMIN ;

select *
from YOUR_EVENT_TABLE
where timestamp > dateadd(hour, -1, current_timestamp())
and RESOURCE_ATTRIBUTES:"snow.service.name" = 'DBT_SNOWPARK_JOB'
order by timestamp desc
limit 100;


----------------------------------------
-- Snowflake Task Error Notifications --
----------------------------------------

use role ACCOUNTADMIN ;

create notification integration dbt_snowpark_failure_notification_integration
    type = EMAIL
    enabled = TRUE
  allowed_recipients = ('email1@email.test', 'user2@email.test')
;

grant usage on integration dbt_snowpark_failure_notification_integration to role DBT_SNOWPARK_ROLE ;


------------------------------
-- Test Email Notifications --
------------------------------

use role DBT_SNOWPARK_ROLE ;

call SYSTEM$SEND_EMAIL(
    integration_name => 'dbt_snowpark_failure_notification_integration',
    'email1@email.test, email2@email.test',
    'Test Snowpark Task Error',
    'Test'
);

-----------------------------------------
-- Snowpark dbt run Procedure Creation --
-----------------------------------------

create or replace procedure run_dbt_snowpark()
  returns string
  language sql
  execute as caller
as
declare
    error_message STRING ;
begin
    -- 1. Clean Service if needed
    drop service if exists 
        dbt_snowpark_db.jaffle_shop_snowpark.dbt_snowpark_job ;

    -- Execute Job
    execute job service
      in compute pool DBT_SNOWPARK_COMPUTE_POOL
      name = 'dbt_snowpark_db.jaffle_shop_snowpark.dbt_snowpark_job'
      from specification $$
        spec:
          containers:
          - name: dbt-job
            image: xxxxx-xxxxxx.registry.snowflakecomputing.com/dbt_snowpark_db/jaffle_shop_snowpark/image_repository/dbt-snowpark
            command: [ "python", "/usr/dbt/entrypoint.py", "--command", "dbt run --target snowpark && dbt run --target snowpark" ]
      $$;
      return 'Snowpark dbt job completed successfully!' ;
exception
  when OTHER then
    error_message := 'Snowpark dbt Run failed.\n' || 'SQL Code: ' || SQLCODE || '\n' || 'Error Message: ' || SQLERRM || '\n' || 'SQL State: ' || SQLSTATE || '\nPlease check the Events Table to access the dbt logs.';
    
    call SYSTEM$SEND_EMAIL(
        'dbt_snowpark_failure_notification_integration',
        'email1@email.test, email2@email.test',
        'Snowpark dbt job Failure',
        :error_message );

    return error_message;
end;

------------------------------------ 
-- Snowpark dbt run Procedure run --
------------------------------------

use role DBT_SNOWPARK_ROLE ;
call run_dbt_snowpark() ;


--------------------------------
-- Snowflake Task Permissions --
--------------------------------

use role ACCOUNTADMIN ;
grant EXECUTE TASK on account to role DBT_SNOWPARK_ROLE ;

use role SECURITYADMIN ;
grant CREATE TASK, EXECUTE TASK on schema DBT_SNOWPARK_DB.JAFFLE_SHOP_SNOWPARK to role DBT_SNOWPARK_ROLE ;


-----------------------------
-- Snowflake Task Creation --
-----------------------------

use role DBT_SNOWPARK_ROLE ;

create or replace task DBT_SNOWPARK_DAILY_RUN_TASK
  warehouse = DBT_SNOWPARK_WH
  schedule = 'USING CRON 0 7 * * * Europe/Amsterdam' -- Every day, 7AM CET
  AS
    call run_dbt_snowpark()
;

show tasks ;

-------------------------------------
-- Snowflake Task Manual Execution --
-------------------------------------

use role DBT_SNOWPARK_ROLE ;
execute task DBT_SNOWPARK_DAILY_RUN_TASK ;
