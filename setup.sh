mkdir install_db
cd install_db

cp ../setup_files/setup_database.sql ./

mkdir 01_structure
cd 01_structure

# Download the OMOP database structure
curl -o omop_ddl.sql https://raw.githubusercontent.com/OHDSI/CommonDataModel/master/PostgreSQL/OMOP%20CDM%20postgresql%20ddl.txt
# The actions below are actually for post-processing
curl -o omop_indexes.sql https://raw.githubusercontent.com/OHDSI/CommonDataModel/master/PostgreSQL/OMOP%20CDM%20postgresql%20pk%20indexes.txt
curl -o omop_constraints.sql https://raw.githubusercontent.com/OHDSI/CommonDataModel/master/PostgreSQL/OMOP%20CDM%20postgresql%20constraints.txt

cd ../
mkdir 02_terminologies
cd 02_terminologies

# Download and extract the omop terminology zip (from my own hosting, as OMOP doesn't give a default zip)
curl -o omop_terminology_package.zip https://jvsoest.eu/omop_terminology_package.zip
unzip omop_terminology_package.zip
cp ../../setup_files/load_terms.sql ./

# setup docker images
docker-compose up -d

sleep 5

# Install database
docker-compose exec postgres psql -U postgres -f /install_db/setup_database.sql