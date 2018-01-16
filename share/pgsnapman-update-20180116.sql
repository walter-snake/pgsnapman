alter table pgsnap_worker add column restore_worker_id integer;

DROP VIEW mgr_worker;

CREATE OR REPLACE VIEW mgr_worker AS 
 SELECT pgsnap_worker.id,
    pgsnap_worker.dns_name,
    pgsnap_worker.status,
    pgsnap_worker.cron_cacheconfig,
    pgsnap_worker.cron_singlejob,
    pgsnap_worker.cron_clean,
    pgsnap_worker.cron_upload,
    pgsnap_worker.comment,
    coalesce (pgsnap_worker.restore_worker_id::text, '') as restore_worker_id,
    to_char(pgsnap_worker.date_added, 'YYYY-MM-DD HH24:MI:SS'::text) AS date_added
   FROM pgsnap_worker
  ORDER BY pgsnap_worker.dns_name;

