# pgsnapman
Postgres snapshot - logical dump manager

## Purpose - goals

* Making automated and controlled dumps of many databases on many database servers, using 1 or more servers that perform the actual dumps ('workers').
* Dump types: full database dump, schema-only database dump, schema-only cluster dump.
* Databases dumps can dump all schema's or just one, to create separate jobs on a per schema base.
* Configured backups always continue running, even when the configuration database is not available (in fact, it would be possible to run and configure them even without the catalog server).
* Restoring dumps to the same or a different database server.
* Fully automated copying of databases, within the same server or between servers (a dump triggers a restore).
* Besides automatic dump and restore, also handling ad-hoc dumps and restores.
* Having a catalog of available dumps.
* Deduplication of the dump data.
* Data stored on the workers in a way that the dump catalog can be rebuild from file.
* Besides directly controlling psql, pg_dump, pg_umpll and pg_restore, scripts can be started as well to accomplish more complex dump/restore scenario's, with the advantage that they can make use of the same logging, messaging and catalog structure.

## Architecture

* Central database containing dump configuration.
* One or more worker servers, that perform the dumps and restores.
* The worker servers retrieve their configuration on a scheduled base, and cache the configuratioan.
* The worker servers perform all scheduled tasks from the cache, always (loosing connection to the central database does not stop backup up).
* Ad-hoc dumps and restores run independent of the scheduled dumps and restores (and require the central database).
* Catalog data and messages can be sent to the catalog database, uploaded by a separate process (to prevent stalling when the central database is not available).

## Restore

Databases can be restored on the same or a different server, with or without tablespace assignments.

### tablespaces
Tablespaces are set in the output of pg_restore, unless --no-tablespaces flag is set. There's one exception: the CREATE DATABASE statement always includes the TABLESPACE assigment, if the database was created with one, even when the --no-tablespaces flag is set. Therefore, in order to allow for restore on another server, it should be possible to create the database without tablespace assignment.

### ACLs
The ACLs of all objects inside a database are in the database dump, however the ACL of the database itself is a global object, and can only be obtained from a dump by creating a (schema-only) cluster dump using pg_dumpall. This is extremely expensive with many databases on a server (could take minutes), so we didn't want to include this step when dumping every single database. Instead, the database acl is read from the pg_catalog.pg_database table, and transformed in the appropriate GRANT/REVOKE statement.

### roles
