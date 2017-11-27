# pgsnapman
Postgres snapshot - logical dump manager

## Restore

Databases can be restored on the same or a different server, with or without tablespace assignments.

### tablespaces
Tablespaces are set in the output of pg_restore, unless --no-tablespaces flag is set. There's one exception: the CREATE DATABASE statement always includes the TABLESPACE defintion, if the database was created with one, even when the --no-tablespaces flag is set. Therefore, in order to allow for restore on another server, it should be possible to create the database without tablespace assignment.

### ACLs
The ACLs of all objects inside a database are in the database dump, however the ACL of the database itself is a global object, and can only be obtained from a dump by creating a (schema-only) cluster dump using pg_dumpall. This is extremely expensive with many databases on a server (could take minutes), so we didn't want to include this step when dumping every single database. Instead, the database acl is read from the pg_catalog.pg_database table, and transformed in the appropriate GRANT/REVOKE statement.

### roles
