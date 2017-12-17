-- update default database status on auto add
alter table pgsql_instance
  add column def_jobstatus text default 'INHERIT';

alter table pgsql_instance add check (def_jobstatus in ('INHERIT', 'HALTED', 'ACTIVE'));

create function get_defjobstatus(pgsqlid integer) returns text as
$$
  select def_jobstatus from pgsql_instance where id = $1;
$$
language 'sql';
