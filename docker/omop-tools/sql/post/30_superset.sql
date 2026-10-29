-- Metadata database for Superset and a read-only role for its dashboards
SELECT format('CREATE ROLE superset LOGIN PASSWORD %L', :'superset_db_password')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'superset') \gexec
ALTER ROLE superset PASSWORD :'superset_db_password';
SELECT 'CREATE DATABASE superset OWNER superset'
 WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'superset') \gexec

SELECT format('CREATE ROLE superset_reader LOGIN PASSWORD %L', :'superset_reader_password')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'superset_reader') \gexec
ALTER ROLE superset_reader PASSWORD :'superset_reader_password';
ALTER ROLE superset_reader SET default_transaction_read_only = on;

GRANT CONNECT ON DATABASE omop TO superset_reader;
GRANT USAGE ON SCHEMA public, dqd_results TO superset_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public, dqd_results TO superset_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE dqd IN SCHEMA dqd_results GRANT SELECT ON TABLES TO superset_reader;
