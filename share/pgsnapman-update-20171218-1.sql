
drop view mgr_copyjob;

create or replace view mgr_copyjob as
with dj_rj as (select d.id as djid, unnest(string_to_array(d.pgsnap_restorejob_id, ','))::integer rjid
  from pgsnap_dumpjob d
  where not (d.pgsnap_restorejob_id is null or d.pgsnap_restorejob_id = '')
)
select d.id
  , r.id as rid
  , pd.dns_name || ':' || pd.pgport as src_pgsql_instance, d.dbname as src_dbname, d.dumpschema as src_schema, d.dumptype as dtype
  , substr(d.jobtype, 1,1) || '/' || d.cron as schedule, d.status as dstatus
  , rd.dns_name || ':' || rd.pgport as dest_pgsql_instance, r.dest_dbname as dest_dbname, r.restoreschema as dest_schema
  , r.restoretype as rtype, r.status as rstatus
from pgsnap_dumpjob d
join dj_rj l
  on l.djid = d.id
join pgsnap_restorejob r
  on r.id = l.rjid
join pgsql_instance pd
  on pd.id = d.pgsql_instance_id
join pgsql_instance rd
  on rd.id = d.pgsql_instance_id
order by d.dbname, pd.dns_name, pd.pgport
;

drop view mgr_copyjob_detail;

create or replace view mgr_copyjob_detail as
with dj_rj as (select d.id as djid, unnest(string_to_array(d.pgsnap_restorejob_id, ','))::integer rjid
  from pgsnap_dumpjob d
  where not (d.pgsnap_restorejob_id is null or d.pgsnap_restorejob_id = '')
)
select d.id
  , r.id as rid
  , pd.dns_name || ':' || pd.pgport as src_pgsql_instance, d.dbname as src_dbname, d.dumpschema as src_schema, d.dumptype as dtype
  , substr(d.jobtype, 1,1) || '/' || d.cron as schedule, d.status as dstatus, coalesce(d.comment, '') as dcomment
  , rd.dns_name || ':' || rd.pgport as dest_pgsql_instance, r.dest_dbname as dest_dbname, r.restoreschema as dest_schema
  , r.restoretype as rtype, r.status as rstatus, coalesce(r.comment, '') as rcomment
from pgsnap_dumpjob d
join dj_rj l
  on l.djid = d.id
join pgsnap_restorejob r
  on r.id = l.rjid
join pgsql_instance pd
  on pd.id = d.pgsql_instance_id
join pgsql_instance rd
  on rd.id = d.pgsql_instance_id
order by d.id, r.id
;

	