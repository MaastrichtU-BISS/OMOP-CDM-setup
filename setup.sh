mkdir install_db
cd install_db

cp ../setup_files/setup_database.sql ./

mkdir 01_structure
cd 01_structure

# Download the OMOP database structure
curl -o omop_ddl.sql https://raw.githubusercontent.com/OHDSI/CommonDataModel/refs/tags/v5.4.0/inst/ddl/5.4/postgresql/OMOPCDM_postgresql_5.4_ddl.sql
# The actions below are actually for post-processing
curl -o omop_indexes.sql https://raw.githubusercontent.com/OHDSI/CommonDataModel/refs/tags/v5.4.0/inst/ddl/5.4/postgresql/OMOPCDM_postgresql_5.4_indices.sql
curl -o omop_constraints.sql https://raw.githubusercontent.com/OHDSI/CommonDataModel/refs/tags/v5.4.0/inst/ddl/5.4/postgresql/OMOPCDM_postgresql_5.4_constraints.sql
curl -o omop_primary_keys.sql https://raw.githubusercontent.com/OHDSI/CommonDataModel/refs/tags/v5.4.0/inst/ddl/5.4/postgresql/OMOPCDM_postgresql_5.4_primary_keys.sql

# Fix the CDM schema name
sed -i 's/@cdmDatabaseSchema/public/g' omop_ddl.sql
sed -i 's/@cdmDatabaseSchema/public/g' omop_indexes.sql
sed -i 's/@cdmDatabaseSchema/public/g' omop_constraints.sql
sed -i 's/@cdmDatabaseSchema/public/g' omop_primary_keys.sql

cd ../
mkdir 02_terminologies
cd 02_terminologies

## Download and extract the omop terminology zip (from my own hosting, as OMOP doesn't give a default zip)
#curl -o omop_terminology_package.zip https://jvsoest.eu/omop_terminology_package.zip
#unzip omop_terminology_package.zip
#cp ../../setup_files/load_terms.sql ./

# setup docker images
docker-compose up -d

sleep 5

# Install database
docker-compose exec postgres psql -U postgres -f /install_db/setup_database.sql
