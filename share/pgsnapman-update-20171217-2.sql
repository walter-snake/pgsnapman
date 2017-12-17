-- Database overview
CREATE OR REPLACE VIEW mgr_database AS 
 SELECT 
    dbname
    , dns_name
    , pgport
   FROM pgsnap_dumpjob d
   JOIN pgsql_instance p
     ON p.id = d.pgsql_instance_id
  GROUP BY dns_name, pgport, dbname
  ORDER BY lower(dbname);

-- drop old views
drop view catalog_compact;
drop view dumpjob_compact;
drop view instance_compact;
drop view restorejob_compact;
