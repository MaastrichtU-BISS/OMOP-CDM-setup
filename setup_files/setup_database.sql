CREATE DATABASE omop;
GRANT ALL PRIVILEGES ON DATABASE omop TO postgres;

\c omop

-- load OMOP table structure
\i /install_db/01_structure/omop_ddl.sql;

-- load terminologies
\i /install_db/02_terminologies/load_terms.sql;

-- load indexes and constraints
\i /install_db/01_structure/omop_indexes.sql;

\i /install_db/01_structure/omop_constraints.sql;
