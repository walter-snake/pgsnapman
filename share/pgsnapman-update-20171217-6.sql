-- View: mgr_restorejob

DROP VIEW mgr_restorejob;

CREATE OR REPLACE VIEW mgr_restorejob AS 
 SELECT j.id,
    coalesce(c.id::text, 'N/A') AS cat_id,
    coalesce(c.dbname, 'N/A') AS src_dbname,
    (p.dns_name || ':'::text) || p.pgport AS dest_pgsql,
    j.dest_dbname,
    j.restoreschema AS schema,
    j.restoretype AS type,
    j.restoreoptions AS options,
        CASE
            WHEN j.jobtype = 'TRIGGER'::text THEN j.jobtype
            ELSE ("substring"(j.jobtype, 1, 1) || '/'::text) || j.cron
        END AS schedule,
    j.status,
    j.comment,
    COALESCE(w.dns_name, '(trigger)'::text) AS pgsnap_worker
   FROM pgsnap_restorejob j
     JOIN pgsql_instance p ON p.id = j.dest_pgsql_instance_id
     LEFT JOIN pgsnap_catalog c ON c.id = j.pgsnap_catalog_id
     LEFT JOIN pgsnap_worker w ON w.id = c.bu_worker_id
  ORDER BY c.dbname;
