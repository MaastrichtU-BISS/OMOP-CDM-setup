# OMOP CDM setup

This repository creates a basic OMOP database within a postgres docker container.

## Prerequisites
* Docker (please find installation [here](https://docs.docker.com/get-docker/))
* Command-line tools:
  * curl
  * unzip (only needed to unzip the downloaded OMOP terminology files)

## Setup
Please download/checkout this repository, and run the [./setup.sh](./setup.sh) file.

## How to use it?
After executing the setup, there should be two docker containers:
* Postgres database
* Postgres web-interface

To launch the webinterface, go to [http://localhost:5555](http://localhost:5555) and sign in with the following credentials:
* Username: admin@omop.tld
* Password: 1234567890

Afterwards, add the postgres database server (Servers -> right-click "Create" -> "Server"). Use the following information to make the server connnection:
* hostname: postgres
* username: postgres
* password: postgres

After connecting to the database server, there should be an omop database available.
