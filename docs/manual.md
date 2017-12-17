# PgSnapMan

## Contents

* [What and why](pgsnapman.md)
* [User manual](manual.md)
  * [Installation](installation.md)
  * [Managing workers](workers.md)
  * [Managing postgres instances](instances.md)
  * [Managing dumps](dumps.md)
  * [Managing restores](restores.md)
  * [Database/data copying](db-data-copy.md)
  * [Retention policy/cleaning](cleaning.md)
* [Reference documentation](reference.md)

## System overview

In order to make proper decisions on how to set up PgSnapMan, 

PgSnapMan consists of 3 main components:
1. Configuration database
1. Worker tools
1. Manager application



### Configuration database
PgSnapMan is built around a central configuration database, of a fairly simple design. It is that simple, that anyone with some database knowledge could fill the database and get the system up and running.

### PgSnapMan worker tools
Every server that has to act as a PgSnapMan server, actually taking the backups (a 'worker'), uses a set of Bash scripts, which are driven by the cron scheduler.

They interact with the catalog database and registered Postgres instances:
* automatically detect (and include if desired) new databases
* getting configurations
* uploading messages
* setting status

They take the backups:
* started by cron, using a cached configuration for the repeated jobs and
* checking the catalog database for dumps to run right now
* connect to a Postgres instance and take the dump using standard Postgres pg_dump and pg_dumpall
* collect additional information needed for a complete restore including all acl's and roles
* at finishing the backup, it can start restore operations
* performs deduplication of the table data files

They perform the restores:
* started by cron and 
* checking the catalog database for restores to run right now or
* using standard Postgres pg_restore and psql
* partial restores that are able to create the target database and schema (impossible with the standard pg_restore tool), including database acl and role creation, checks for tablespaces
* restore to a different database and/or on a different Postgres instance

Other:
* removing old backups, according to a schedule (keep daily, weekly, monthly, yearly) to thin out backups over time
* log rotation
* uploading message data to the catalog database

Great care has been taking to make sure that each worker can continue performing it's scheduled dump tasks independently and without reliance on a central database.

### Manager application
The management is facilitated by an easy to use Python plain commandline application.
* add/remove jobs
* regulating catalog clean-up
* set schedules
* list/search backup catalog
* list restore log
* check messages

This application can run on Windows too.

