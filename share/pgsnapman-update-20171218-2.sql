-- View: mgr_dumpjob
DROP VIEW mgr_dumpjob;

CREATE OR REPLACE VIEW mgr_dumpjob AS 
 SELECT vw_dumpjob_worker_instance.id,
    (vw_dumpjob_worker_instance.pgsql_instance_dns_name || ':'::text) || vw_dumpjob_worker_instance.pgsql_instance_port AS pgsql,
    vw_dumpjob_worker_instance.dbname,
    vw_dumpjob_worker_instance.dumpschema AS schema,
    vw_dumpjob_worker_instance.dumptype AS type,
    COALESCE(vw_dumpjob_worker_instance.pgsnap_restorejob_id, ''::text) AS restorejob,
    ("substring"(vw_dumpjob_worker_instance.jobtype, 1, 1) || '/'::text) || vw_dumpjob_worker_instance.cron AS schedule,
    vw_dumpjob_worker_instance.status,
    substr(vw_dumpjob_worker_instance.comment, 1, 32) AS comment,
    vw_dumpjob_worker_instance.pgsnap_worker_dns_name AS pgsnap_worker
   FROM vw_dumpjob_worker_instance
  ORDER BY (lower(vw_dumpjob_worker_instance.dbname) || '.'::text) || lower(vw_dumpjob_worker_instance.dumpschema);
