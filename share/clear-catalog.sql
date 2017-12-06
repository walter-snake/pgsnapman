-- Create a basic example/test configuration

-- completely clear pgsnapman catalog
delete from pgsnap_message ;
delete from pgsnap_restorelog ;
delete from pgsnap_catalog ;
delete from pgsnap_dumpjob ;
delete from pgsnap_restorejob ;
delete from pgsnap_worker;
delete from pgsql_instance ;
delete from pgsnap_default;
delete from pgsnap_script;

-- rebuild a demo catalog
-- reset sequences
SELECT setval('public.pgsnap_default_id_seq', 1, false);
SELECT setval('public.pgsql_instance_id_seq', 1, false);
SELECT setval('public.pgsnap_worker_id_seq', 1, false);
SELECT setval('public.pgsnap_restorejob_id_seq', 1, false);
SELECT setval('public.pgsnap_dumpjob_id_seq', 1, false);
SELECT setval('public.pgsnap_catalog_id_seq', 1, false);
SELECT setval('public.pgsnap_restorelog_id_seq', 1, false);
SELECT setval('public.pgsnap_message_id_seq', 1, false);
SELECT setval('public.pgsnap_script_id_seq', 1, false);

-- insert retention policy on job delete
insert into pgsnap_default (key, value) values ('retention_on_delete', '14|2|0|0');

-- create a postgres server to backup instance
-- local postgres server on the pgsnapman host
insert into pgsql_instance (dns_name, pgport, comment, pgsnap_worker_id_default) values ('local', 5432, 'our own local server', null);
insert into pgsql_instance (dns_name, pgport, comment, pgsnap_worker_id_default) values ('localhost', 5433, 'our test server on port 5433', 1);
insert into pgsql_instance (dns_name, pgport, comment, pgsnap_worker_id_default) values ('domitian', 5434, 'our second test server on port 5434', null);
insert into pgsnap_worker (dns_name, comment) values ('domitian', 'pgsnap worker');

-- manually create the entry for the pgsnapman database on localhost (no need to have it on this host)
-- note that we have to provide the worker: this instance has no default worker set for demo purposes
select put_dumpjob(1, 1, 'pgsnapman', '*', 'our PgSnapMan catalog database');


