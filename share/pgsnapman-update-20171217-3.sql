-- View: mgr_instance

DROP VIEW mgr_instance;

CREATE OR REPLACE VIEW mgr_instance AS 
 SELECT p.id,
    p.dns_name,
    p.pgport as port,
    p.pgsql_superuser AS superuser,
    p.status,
    p.bu_window_start AS hr_s,
    p.bu_window_end AS hr_e,
    w.dns_name || ' (' || substr(def_jobstatus, 1,1) || ')'	 AS def_worker_addjobstatus,
    p.comment,
    to_char(p.date_added, 'YYYY-MM-DD HH24:MI:SS'::text) AS date_added
   FROM pgsql_instance p
     LEFT JOIN pgsnap_worker w ON w.id = p.pgsnap_worker_id_default
  ORDER BY p.dns_name, p.pgport;
