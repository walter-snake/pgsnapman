-- View: mgr_copyjob

DROP VIEW mgr_copyjob;

CREATE OR REPLACE VIEW mgr_copyjob AS 
 WITH dj_rj AS (
         SELECT d_1.id AS djid,
            unnest(string_to_array(d_1.pgsnap_restorejob_id, ','::text))::integer AS rjid
           FROM pgsnap_dumpjob d_1
          WHERE NOT (d_1.pgsnap_restorejob_id IS NULL OR d_1.pgsnap_restorejob_id = ''::text)
        )
 SELECT d.id,
    r.id AS rid,
    (pd.dns_name || E'\n'::text) || pd.pgport AS s_pgsql,
    d.dbname AS s_dbname,
    d.dumpschema AS s_dschema,
    d.dumptype AS s_dtype,
    (substr(d.jobtype, 1, 1) || '/'::text) || d.cron AS schedule,
    d.status AS dstatus,
    (rd.dns_name || E'\n'::text) || rd.pgport AS d_pgsql,
    r.dest_dbname as d_dbname,
    r.restoreschema AS d_rschema,
    r.restoretype AS d_rtype,
    r.status AS rstatus,	
    to_char(d.date_added, E'YYYY-MM-DD\nHH24:MI:SS'::text) AS date_added
   FROM pgsnap_dumpjob d
     JOIN dj_rj l ON l.djid = d.id
     JOIN pgsnap_restorejob r ON r.id = l.rjid
     JOIN pgsql_instance pd ON pd.id = d.pgsql_instance_id
     JOIN pgsql_instance rd ON rd.id = d.pgsql_instance_id
  ORDER BY d.dbname, pd.dns_name, pd.pgport;

DROP VIEW mgr_restorejob;

CREATE OR REPLACE VIEW mgr_restorejob AS 
 SELECT j.id,
    COALESCE(c.id::text, 'N/A'::text) AS cat_id,
    COALESCE(c.dbname, 'N/A'::text) AS s_dbname,
    (p.dns_name || E'\n'::text) || p.pgport AS d_pgsql,
    j.dest_dbname as d_dbname,
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
    to_char(j.date_added, E'YYYY-MM-DD\nHH24:MI:SS'::text) AS date_added
   FROM pgsnap_restorejob j
     JOIN pgsql_instance p ON p.id = j.dest_pgsql_instance_id
     LEFT JOIN pgsnap_catalog c ON c.id = j.pgsnap_catalog_id
     LEFT JOIN pgsnap_worker w ON w.id = c.bu_worker_id
  ORDER BY c.dbname;

DROP VIEW mgr_dumpjob;
	
CREATE OR REPLACE VIEW mgr_dumpjob AS 
 SELECT vw_dumpjob_worker_instance.id,
    (vw_dumpjob_worker_instance.pgsql_instance_dns_name || E'\n'::text) || vw_dumpjob_worker_instance.pgsql_instance_port AS pgsql,
    vw_dumpjob_worker_instance.dbname,
    vw_dumpjob_worker_instance.dumpschema AS schema,
    vw_dumpjob_worker_instance.dumptype AS type,
    COALESCE(vw_dumpjob_worker_instance.pgsnap_restorejob_id, ''::text) AS restorejob,
    ("substring"(vw_dumpjob_worker_instance.jobtype, 1, 1) || '/'::text) || vw_dumpjob_worker_instance.cron AS schedule,
    vw_dumpjob_worker_instance.status,
    substr(vw_dumpjob_worker_instance.comment, 1, 32) AS comment,
    vw_dumpjob_worker_instance.pgsnap_worker_dns_name AS pgsnap_worker,
    to_char(date_added, E'YYYY-MM-DD\nHH24:MI:SS'::text) AS date_added
   FROM vw_dumpjob_worker_instance
   JOIN pgsnap_dumpjob
     ON vw_dumpjob_worker_instance.id = pgsnap_dumpjob.id
  ORDER BY (lower(vw_dumpjob_worker_instance.dbname) || '.'::text) || lower(vw_dumpjob_worker_instance.dumpschema);

DROP VIEW mgr_restorelog;

CREATE OR REPLACE VIEW mgr_restorelog AS 
 SELECT pgsnap_restorelog.id,
    pgsnap_restorelog.src_dbname as s_dbname,
    (pgsnap_restorelog.pgsql_dns_name || E'\n'::text) || pgsnap_restorelog.pgsql_port AS d_pgsql,
    (((pgsnap_restorelog.pgsnap_restorejob_id || '/'::text) || pgsnap_restorelog.dest_dbname) || '.'::text) || pgsnap_restorelog.restoreschema AS id_db_schema,
    pgsnap_restorelog.restoretype,
    to_char(pgsnap_restorelog.starttime, E'YYYY-MM-DD\nHH24:MI:SS'::text) AS starttime,
    pgsnap_restorelog.endtime - pgsnap_restorelog.starttime AS duration,
    pgsnap_restorelog.status,
    substr(pgsnap_restorelog.message, 1, 32) AS message,
    w.dns_name AS pgsnap_worker
   FROM pgsnap_restorelog
     LEFT JOIN pgsnap_worker w ON w.id = pgsnap_restorelog.bu_worker_id
  ORDER BY to_char(pgsnap_restorelog.starttime, 'YYYY-MM-DD HH24:MI:SS'::text);

DROP VIEW mgr_database;

CREATE OR REPLACE VIEW mgr_database AS 
 SELECT d.dbname,
    p.dns_name,
    p.pgport,
    to_char(d.date_added, E'YYYY-MM-DD'::text) AS date_added
   FROM pgsnap_dumpjob d
     JOIN pgsql_instance p ON p.id = d.pgsql_instance_id
  GROUP BY p.dns_name, p.pgport, d.dbname, d.date_added
  ORDER BY lower(d.dbname);
