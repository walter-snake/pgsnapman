-- View: mgr_restorejob

DROP VIEW mgr_restorejob;

CREATE OR REPLACE VIEW mgr_restorejob AS 
 SELECT j.id,
    COALESCE(c.id::text, 'N/A'::text) AS cat_id,
    COALESCE(c.dbname || '.' || c.dumpschema , 'N/A'::text) AS s_db_schema,
    (p.dns_name || '
'::text) || p.pgport AS d_pgsql,
    j.dest_dbname AS d_dbname,
    j.restoreschema AS d_rschema,
    j.restoretype AS d_rtype,
    j.restoreoptions AS options,
        CASE
            WHEN j.jobtype = 'TRIGGER'::text THEN j.jobtype
            ELSE ("substring"(j.jobtype, 1, 1) || '/'::text) || j.cron
        END AS schedule,
    j.status,
    j.comment,
    COALESCE(w.dns_name, '(trigger)'::text) AS pgsnap_worker,
    to_char(j.date_added, 'YYYY-MM-DD
HH24:MI:SS'::text) AS date_added
   FROM pgsnap_restorejob j
     JOIN pgsql_instance p ON p.id = j.dest_pgsql_instance_id
     LEFT JOIN pgsnap_catalog c ON c.id = j.pgsnap_catalog_id
     LEFT JOIN pgsnap_worker w ON w.id = c.bu_worker_id
  ORDER BY c.dbname;

-- View: mgr_copyjob

DROP VIEW mgr_copyjob;

CREATE OR REPLACE VIEW mgr_copyjob AS 
 WITH dj_rj AS (
         SELECT d_1.id AS djid,
            unnest(string_to_array(d_1.pgsnap_restorejob_id, ','::text))::integer AS rjid
           FROM pgsnap_dumpjob d_1
          WHERE NOT (d_1.pgsnap_restorejob_id IS NULL OR d_1.pgsnap_restorejob_id = ''::text)
        )
 SELECT d.id as did,
    (pd.dns_name || E'\n'::text) || pd.pgport as s_pgsql,
    d.dbname || '.' || d.dumpschema AS s_db_schema,
    d.dumptype AS s_dtype,
    (substr(d.jobtype, 1, 1) || '/'::text) || d.cron AS schedule,
    d.status AS dstatus,
    r.id AS rid,
    (rd.dns_name || '
'::text) || rd.pgport AS d_pgsql,
    r.dest_dbname || '.' || r.restoreschema AS d_db_schema,
    r.restoretype AS d_rtype,
    r.status AS rstatus,
    to_char(d.date_added, 'YYYY-MM-DD
HH24:MI:SS'::text) AS date_added
   FROM pgsnap_dumpjob d
     JOIN dj_rj l ON l.djid = d.id
     JOIN pgsnap_restorejob r ON r.id = l.rjid
     JOIN pgsql_instance pd ON pd.id = d.pgsql_instance_id
     JOIN pgsql_instance rd ON rd.id = d.pgsql_instance_id
  ORDER BY d.dbname, pd.dns_name, pd.pgport;

