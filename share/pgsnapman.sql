--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: del_catalog(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION del_catalog(cat_id integer) RETURNS void
    LANGUAGE sql
    AS $_$delete from pgsnap_catalog where id = $1;$_$;


--
-- Name: get_catalogidexists(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_catalogidexists(catid integer) RETURNS integer
    LANGUAGE sql
    AS $_$
select count(*)::integer from pgsnap_catalog where id = $1;
$_$;


--
-- Name: get_databaseexists(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_databaseexists(dbname text) RETURNS integer
    LANGUAGE sql
    AS $_$
select count(*)::integer from pg_database where datname = $1;
$_$;


--
-- Name: get_default(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_default(key text) RETURNS text
    LANGUAGE sql
    AS $_$select value from pgsnap_default where key = $1;$_$;


--
-- Name: get_defaultworker(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_defaultworker(pgsqlinstance integer) RETURNS integer
    LANGUAGE sql
    AS $_$
select pgsnap_worker_id_default from pgsql_instance where id = $1;
$_$;


--
-- Name: get_dumpjobstatus(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_dumpjobstatus(jobid integer) RETURNS text
    LANGUAGE sql
    AS $_$select status from pgsnap_dumpjob where id = $1;$_$;


--
-- Name: get_globalacl(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_globalacl(dbname text) RETURNS record
    LANGUAGE sql
    AS $_$
with acls as (select datname, split_part(acl, '=', 1) as acl_role
  , (regexp_split_to_array(acl, '[=/]'))[2] as acl_rights
from (select datname, unnest(datacl)::text as acl
  from pg_database) a
)
select * from acls
where datname = $1;
$_$;


--
-- Name: get_hasjob(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_hasjob(pgsql_id integer, dbname text) RETURNS text
    LANGUAGE sql
    AS $_$select 'YES'::text from pgsnap_dumpjob j join pgsql_instance p on p.id = j.pgsql_instance_id where pgsql_instance_id = $1 and dbname = $2;$_$;


--
-- Name: get_keep_catjobid(timestamp with time zone, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_keep_catjobid(datenow timestamp with time zone, jobid integer, days integer, weeks integer, months integer, years integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
declare
  keep_slicestart timestamp with time zone;
  keep_sliceend timestamp with time zone;
  dj record;
  r record;
  keep_id record;
  keep_ids integer[];
begin

  -- initialize, end of first slice
  keep_sliceend := $1::date + ('1 day')::interval;
  keep_ids := ARRAY[]::integer[];

  -- 1 per day
  --raise notice 'Daily clean up, end date at start: %', keep_sliceend;
  for i in 1..days loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' days')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend) overlaps (starttime, starttime)
        and status = 'SUCCESS'
        and pgsnap_dumpjob_id = jobid
        and keep = 'AUTO'
      order by starttime desc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'D % % [%..%]', i, r.id, keep_slicestart, keep_sliceend;    
    end loop;
    -- set new slice end date
    keep_sliceend := keep_slicestart;
  end loop;
    
  -- 1 per week
  --raise notice 'Weekly clean up, end date at start: %', keep_sliceend;
  for i in 1..weeks loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' weeks')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend) overlaps (starttime, starttime)
        and status = 'SUCCESS'
        and pgsnap_dumpjob_id = jobid
        and keep = 'AUTO'
      order by starttime asc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'W % % [%..%]', i, r.id, keep_slicestart, keep_sliceend;    
    end loop;
    -- set new slice end date
    keep_sliceend := keep_slicestart;
  end loop;
  
  -- 1 per month
  --raise notice 'Monthly clean up, end date at start: %', keep_sliceend;
  for i in 1..months loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' months')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend) overlaps (starttime, starttime)
        and status = 'SUCCESS'
        and pgsnap_dumpjob_id = jobid
        and keep = 'AUTO'
     order by starttime asc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'M % % [%..%]', i, r.id, keep_slicestart, keep_sliceend;    
    end loop;
    -- set new slice end date
    keep_sliceend := keep_slicestart;
  end loop;


  -- 1 per year
  --raise notice 'Yearly clean up, end date at start: %', keep_sliceend;
  for i in 1..years loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' year')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend) overlaps (starttime, starttime)
        and status = 'SUCCESS'
        and pgsnap_dumpjob_id = jobid
        and keep = 'AUTO'
       order by starttime asc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'Y % % [%..%]', i, r.id, keep_slicestart, keep_sliceend;    
    end loop;
    -- set new slice end date
    keep_sliceend := keep_slicestart;
  end loop;

  -- all catalog entries marked as keep, or linked to a restore job
  for r in select id
    from pgsnap_catalog
    where keep = 'YES'
    or id in (select pgsnap_catalog_id from pgsnap_restorejob)
  loop
      if NOT keep_ids @> ARRAY[r.id] then
        keep_ids := array_append(keep_ids, r.id);
      end if;
  end loop;
     
  -- output
  --raise notice 'Keeping: %', array_length(keep_ids, 1);
  for keep_id in select unnest(keep_ids)
  loop
    return next keep_id;
  end loop;
  return;
end;
$_$;


--
-- Name: get_pgsnap_worker_cacheconfigcron(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_pgsnap_worker_cacheconfigcron(workerid integer) RETURNS text
    LANGUAGE sql
    AS $_$select cron_cacheconfig from pgsnap_worker where id = $1;$_$;


--
-- Name: get_pgsnap_worker_cleancron(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_pgsnap_worker_cleancron(workerid integer) RETURNS text
    LANGUAGE sql
    AS $_$select cron_clean from pgsnap_worker where id = $1;$_$;


--
-- Name: get_pgsnap_worker_id(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_pgsnap_worker_id(dns_name text) RETURNS integer
    LANGUAGE sql
    AS $_$select id from pgsnap_worker where dns_name = $1;$_$;


--
-- Name: get_pgsnap_worker_singlejobcron(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_pgsnap_worker_singlejobcron(workerid integer) RETURNS text
    LANGUAGE sql
    AS $_$select cron_singlejob from pgsnap_worker where id = $1;$_$;


--
-- Name: get_pgsnap_worker_uploadcron(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_pgsnap_worker_uploadcron(workerid integer) RETURNS text
    LANGUAGE sql
    AS $_$select cron_upload from pgsnap_worker where id = $1;$_$;


--
-- Name: get_pgsql_instance_id(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_pgsql_instance_id(dns_name text, pgport integer) RETURNS integer
    LANGUAGE sql
    AS $_$select id from pgsql_instance where dns_name = $1 and pgport = $2;$_$;


--
-- Name: get_restorejobstatus(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_restorejobstatus(jobid integer) RETURNS text
    LANGUAGE sql
    AS $_$select status from pgsnap_restorejob where id = $1;$_$;


--
-- Name: get_rndcron(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_rndcron(pgsql_instance_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  pgsqldata record;
  crontime time;
  length integer;
  rnd integer;
begin
  select * into pgsqldata from pgsql_instance where id = pgsql_instance_id;
  length := extract('hour' from (('20000102T' || pgsqldata.bu_window_end || ':00')::timestamp with time zone - ('20000101T' || pgsqldata.bu_window_start || ':00')::timestamp with time zone)::interval)::integer * 60;
  select (random() * length)::integer into rnd;
  select (pgsqldata.bu_window_start || ':00')::time + (rnd::text || ' min')::interval into crontime;
  return extract('min' from crontime) || ' ' || extract('hour' from crontime) || ' * * *' ;
end;
$$;


--
-- Name: get_schemaexists(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_schemaexists(schemaname text) RETURNS integer
    LANGUAGE sql
    AS $_$
select count(*)::integer from pg_namespace where nspname = $1;
$_$;


--
-- Name: get_scriptcode(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_scriptcode(script_name text) RETURNS text
    LANGUAGE sql
    AS $_$select scriptcode from pgsnap_script where scriptname = $1;$_$;


--
-- Name: insert_dumpjob(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION insert_dumpjob() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  IF NEW.cron IS NULL OR NEW.cron = '' THEN
    NEW.cron = get_rndcron(NEW.pgsql_instance_id);
  END IF;
  IF NEW.pgsnap_worker_id IS NULL THEN
    NEW.pgsnap_worker_id = get_defaultworker(NEW.pgsql_instance_id);
  END IF;
  
  RETURN NEW;
end;
$$;


--
-- Name: put_dumpjob(integer, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION put_dumpjob(pgsqlinstanceid integer, dbname text, comment text) RETURNS integer
    LANGUAGE sql
    AS $_$insert into pgsnap_dumpjob (pgsql_instance_id, dbname, comment) values ($1, $2, $3) returning id;$_$;


--
-- Name: put_dumpjob(integer, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION put_dumpjob(pgsqlinstanceid integer, dbname text, comment text, status text) RETURNS integer
    LANGUAGE sql
    AS $_$insert into pgsnap_dumpjob (pgsql_instance_id, dbname, comment, status) values ($1, $2, $3, $4) returning id;$_$;


--
-- Name: put_dumpjob(integer, integer, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION put_dumpjob(pgsnapworkerid integer, pgsqlinstanceid integer, dbname text, schemaname text, comment text) RETURNS integer
    LANGUAGE sql
    AS $_$insert into pgsnap_dumpjob (pgsnap_worker_id, pgsql_instance_id, dbname, dumpschema, comment) values ($1, $2, $3, $4, $5) returning id;$_$;


--
-- Name: put_dumpjob(integer, integer, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION put_dumpjob(pgsnapworkerid integer, pgsqlinstanceid integer, dbname text, schemaname text, comment text, status text) RETURNS integer
    LANGUAGE sql
    AS $_$insert into pgsnap_dumpjob (pgsnap_worker_id, pgsql_instance_id, dbname, dumpschema, comment, status) values ($1, $2, $3, $4, $5, $6) returning id;$_$;


--
-- Name: put_restorelog(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION put_restorelog(resjobid integer, bupath text) RETURNS integer
    LANGUAGE sql
    AS $_$insert into pgsnap_restorelog (pgsnap_restorejob_id, bu_path) values ($1, $2) returning id; $_$;


--
-- Name: set_catalogstatus(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_catalogstatus(cat_id integer, status text) RETURNS void
    LANGUAGE sql
    AS $_$update pgsnap_catalog set status = $2 where id = $1;$_$;


--
-- Name: set_dumpjobstatus(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_dumpjobstatus(job_id integer, status text) RETURNS void
    LANGUAGE sql
    AS $_$update pgsnap_dumpjob set status = $2 where id = $1;$_$;


--
-- Name: set_restorejobstatus(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_restorejobstatus(job_id integer, status text) RETURNS void
    LANGUAGE sql
    AS $_$update pgsnap_restorejob set status = $2 where id = $1;$_$;


--
-- Name: set_restorelog(integer, text, text, text, integer, text, integer, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_restorelog(logid integer, status text, message text, bupath text, buworkerid integer, pgsqldnsname text, pgsqlport integer, destdbname text, restore_schema text, restore_type text) RETURNS void
    LANGUAGE sql
    AS $_$update pgsnap_restorelog set endtime=now()::timestamp with time zone, status=$2, message=$3, bu_path=$4
, bu_worker_id=$5, pgsql_dns_name=$6, pgsql_port=$7, dest_dbname=$8, restoreschema=$9, restoretype=$10
 where id = $1; $_$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: pgsnap_catalog; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_catalog (
    id integer NOT NULL,
    pgsnap_dumpjob_id integer,
    starttime timestamp with time zone,
    endtime timestamp with time zone,
    status text,
    bu_name text,
    bu_location text,
    dbsize bigint,
    dumpsize bigint,
    dbname text,
    dumpschema text,
    dumptype text,
    verified text DEFAULT 'NO'::text,
    keep text DEFAULT 'AUTO'::text,
    bu_extension text,
    pgversion text,
    bu_worker_id integer,
    message text,
    pgsql_dns_name text,
    pgsql_port integer,
    CONSTRAINT pgsnap_catalog_keep_check CHECK ((keep = ANY (ARRAY['NO'::text, 'YES'::text, 'AUTO'::text]))),
    CONSTRAINT pgsnap_catalog_status_check CHECK ((status = ANY (ARRAY['SUCCESS'::text, 'FAILED'::text, 'REMOVING'::text]))),
    CONSTRAINT pgsnap_catalog_verified_check CHECK ((verified = ANY (ARRAY['YES'::text, 'FAILED'::text, 'NO'::text])))
);


--
-- Name: pgsnap_dumpjob; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_dumpjob (
    id integer NOT NULL,
    pgsnap_worker_id integer NOT NULL,
    pgsql_instance_id integer NOT NULL,
    dbname text NOT NULL,
    dumptype text DEFAULT 'FULL'::text,
    dumpschema text DEFAULT '*'::text,
    dumpoptions text,
    keep_daily integer DEFAULT 14,
    keep_weekly integer DEFAULT 2,
    keep_monthly integer DEFAULT 5,
    keep_yearly integer DEFAULT 2,
    comment text,
    cron text NOT NULL,
    status text DEFAULT 'ACTIVE'::text,
    jobtype text DEFAULT 'REPEAT'::text,
    pgsnap_restorejob_id text,
    date_added timestamp with time zone DEFAULT now(),
    CONSTRAINT pgsnap_dumpjob_cron_check CHECK ((cron ~ '^([\*\/0-9,]+\ ){4}[\*\/0-9,]+$'::text)),
    CONSTRAINT pgsnap_dumpjob_dbname_check CHECK ((dbname ~ '^[^".]*$'::text)),
    CONSTRAINT pgsnap_dumpjob_dumpschema_check CHECK ((dumpschema ~ '^[^".]*$'::text)),
    CONSTRAINT pgsnap_dumpjob_dumptype_check CHECK ((dumptype = ANY (ARRAY['FULL'::text, 'SCHEMA'::text, 'CLUSTER_SCHEMA'::text, 'SCRIPT'::text, 'CLUSTER'::text]))),
    CONSTRAINT pgsnap_dumpjob_jobtype_check CHECK ((jobtype = ANY (ARRAY['REPEAT'::text, 'SINGLE'::text]))),
    CONSTRAINT pgsnap_dumpjob_pgsnap_restorejob_id_check CHECK ((pgsnap_restorejob_id ~ '^[0-9,]*$'::text)),
    CONSTRAINT pgsnap_dumpjob_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


--
-- Name: pgsql_instance; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsql_instance (
    id integer NOT NULL,
    dns_name text NOT NULL,
    pgport integer,
    comment text,
    pgsql_superuser text DEFAULT 'postgres'::text,
    status text DEFAULT 'ACTIVE'::text,
    bu_window_start integer DEFAULT 2,
    bu_window_end integer DEFAULT 6,
    pgsnap_worker_id_default integer NOT NULL,
    date_added timestamp with time zone DEFAULT now(),
    CONSTRAINT pgsql_instance_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


--
-- Name: catalog_compact; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW catalog_compact AS
 SELECT c.id,
    p.dns_name,
    p.pgport,
    ((c.dbname || '.'::text) || c.dumpschema) AS dbname,
    c.dumptype,
    c.bu_name,
    c.starttime,
    (c.endtime - c.starttime) AS duration,
    c.status,
    c.verified,
    c.keep,
    c.dbsize,
    c.dumpsize
   FROM ((pgsnap_catalog c
     JOIN pgsnap_dumpjob j ON ((j.id = c.pgsnap_dumpjob_id)))
     JOIN pgsql_instance p ON ((p.id = j.pgsql_instance_id)))
  ORDER BY c.starttime;


--
-- Name: pgsnap_worker; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_worker (
    id integer NOT NULL,
    dns_name text NOT NULL,
    comment text,
    cron_cacheconfig text DEFAULT '15 20 * * *'::text,
    cron_singlejob text DEFAULT '* * * * *'::text,
    cron_clean text DEFAULT '15 18 * * *'::text,
    cron_upload text DEFAULT '*/5 * * * *'::text,
    status text DEFAULT 'ACTIVE'::text,
    date_added timestamp with time zone DEFAULT now(),
    CONSTRAINT pgsnap_worker_cron_cacheconfig_check CHECK ((cron_cacheconfig ~ '^([\*\/0-9,]+\ ){4}[\*\/0-9,]+$'::text)),
    CONSTRAINT pgsnap_worker_cron_clean_check CHECK ((cron_clean ~ '^([\*\/0-9,]+\ ){4}[\*\/0-9,]+$'::text)),
    CONSTRAINT pgsnap_worker_cron_singlejob_check CHECK ((cron_singlejob ~ '^([\*\/0-9,]+\ ){4}[\*\/0-9,]+$'::text)),
    CONSTRAINT pgsnap_worker_cron_upload_check CHECK ((cron_upload ~ '^([\*\/0-9,]+\ ){4}[\*\/0-9,]+$'::text)),
    CONSTRAINT pgsnap_worker_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


--
-- Name: vw_dumpjob_worker_instance; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW vw_dumpjob_worker_instance AS
 SELECT j.id,
    j.pgsnap_worker_id,
    j.pgsql_instance_id,
    j.dbname,
    j.dumptype,
    j.dumpschema,
    j.cron,
    j.keep_daily,
    j.keep_weekly,
    j.keep_monthly,
    j.keep_yearly,
    j.comment,
    j.status,
    j.jobtype,
    b.dns_name AS pgsnap_worker_dns_name,
    p.dns_name AS pgsql_instance_dns_name,
    p.pgport AS pgsql_instance_port,
    p.pgsql_superuser AS pgsql_instance_superuser,
    j.pgsnap_restorejob_id,
    j.dumpoptions
   FROM ((pgsnap_dumpjob j
     JOIN pgsnap_worker b ON ((b.id = j.pgsnap_worker_id)))
     JOIN pgsql_instance p ON ((p.id = j.pgsql_instance_id)));


--
-- Name: dumpjob_compact; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW dumpjob_compact AS
 SELECT vw_dumpjob_worker_instance.id,
    vw_dumpjob_worker_instance.pgsnap_worker_dns_name AS pgs_worker,
    ((vw_dumpjob_worker_instance.pgsql_instance_dns_name || ':'::text) || vw_dumpjob_worker_instance.pgsql_instance_port) AS pgsql_instance,
    vw_dumpjob_worker_instance.jobtype,
    ((vw_dumpjob_worker_instance.dbname || '.'::text) || vw_dumpjob_worker_instance.dumpschema) AS dbname_schema,
    vw_dumpjob_worker_instance.dumptype,
    vw_dumpjob_worker_instance.dumpoptions,
    vw_dumpjob_worker_instance.cron,
    vw_dumpjob_worker_instance.comment,
    vw_dumpjob_worker_instance.status,
    vw_dumpjob_worker_instance.pgsnap_restorejob_id AS restorejob
   FROM vw_dumpjob_worker_instance;


--
-- Name: instance_compact; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW instance_compact AS
 SELECT pgsql_instance.id,
    ((((pgsql_instance.pgsql_superuser || '@'::text) || pgsql_instance.dns_name) || ':'::text) || pgsql_instance.pgport) AS instance,
    pgsql_instance.status,
    pgsql_instance.bu_window_start AS def_start_hour,
    pgsql_instance.bu_window_end AS def_end_hour,
    pgsql_instance.pgsnap_worker_id_default AS default_worker
   FROM pgsql_instance;


--
-- Name: mgr_catalog; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW mgr_catalog AS
 SELECT c.id,
    ((c.pgsql_dns_name || ':'::text) || c.pgsql_port) AS pgsql_instance,
    ((((c.pgsnap_dumpjob_id)::text || '/'::text) || (c.dbname || '.'::text)) || c.dumpschema) AS jobid_dbname,
    c.dumptype,
    to_char(c.starttime, 'YYYY-MM-DD HH24:MI:SS'::text) AS starttime,
    (c.endtime - c.starttime) AS duration,
    c.status,
    c.verified,
    c.keep,
    substr(c.message, 1, 32) AS message,
    w.dns_name AS pgsnap_worker
   FROM (pgsnap_catalog c
     JOIN pgsnap_worker w ON ((w.id = c.bu_worker_id)))
  ORDER BY c.starttime;


--
-- Name: mgr_dumpjob; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW mgr_dumpjob AS
 SELECT vw_dumpjob_worker_instance.id,
    ((vw_dumpjob_worker_instance.pgsql_instance_dns_name || ':'::text) || vw_dumpjob_worker_instance.pgsql_instance_port) AS pgsql_instance,
    vw_dumpjob_worker_instance.dbname,
    vw_dumpjob_worker_instance.dumpschema AS schema,
    vw_dumpjob_worker_instance.dumptype AS type,
    vw_dumpjob_worker_instance.dumpoptions AS options,
    vw_dumpjob_worker_instance.pgsnap_restorejob_id AS restorejob,
    vw_dumpjob_worker_instance.jobtype,
    vw_dumpjob_worker_instance.cron,
    vw_dumpjob_worker_instance.status,
    substr(vw_dumpjob_worker_instance.comment, 1, 32) AS comment,
    vw_dumpjob_worker_instance.pgsnap_worker_dns_name AS pgs_worker
   FROM vw_dumpjob_worker_instance
  ORDER BY ((vw_dumpjob_worker_instance.pgsql_instance_dns_name || ':'::text) || vw_dumpjob_worker_instance.pgsql_instance_port), ((vw_dumpjob_worker_instance.dbname || '.'::text) || vw_dumpjob_worker_instance.dumpschema);


--
-- Name: mgr_instance; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW mgr_instance AS
 SELECT p.id,
    p.dns_name,
    p.pgport,
    p.pgsql_superuser AS superuser,
    p.status,
    p.bu_window_start AS hour_start,
    p.bu_window_end AS hour_end,
    (((w.dns_name || ' ['::text) || p.pgsnap_worker_id_default) || ']'::text) AS def_worker,
    p.comment,
    to_char(p.date_added, 'YYYY-MM-DD HH24:MI:SS'::text) AS date_added
   FROM (pgsql_instance p
     LEFT JOIN pgsnap_worker w ON ((w.id = p.pgsnap_worker_id_default)))
  ORDER BY p.dns_name, p.pgport;


--
-- Name: pgsnap_message; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_message (
    id integer NOT NULL,
    level text,
    pgsnap_tool text,
    logtime timestamp with time zone,
    message text,
    jobclass text,
    jobid integer
);


--
-- Name: mgr_message; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW mgr_message AS
 SELECT pgsnap_message.id,
    pgsnap_message.level,
    pgsnap_message.pgsnap_tool,
    to_char(pgsnap_message.logtime, 'YYYY-MM-DD HH24:MI:SS'::text) AS logtime,
    substr(pgsnap_message.message, 1, 64) AS message,
    pgsnap_message.jobclass,
    pgsnap_message.jobid
   FROM pgsnap_message
  ORDER BY pgsnap_message.id;


--
-- Name: pgsnap_restorejob; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_restorejob (
    id integer NOT NULL,
    dest_pgsql_instance_id integer NOT NULL,
    dest_dbname text NOT NULL,
    restoretype text DEFAULT 'FULL'::text,
    restoreschema text DEFAULT '*'::text NOT NULL,
    restoreoptions text DEFAULT ''::text,
    existing_db text DEFAULT 'RENAME'::text,
    status text DEFAULT 'ACTIVE'::text,
    comment text,
    jobtype text DEFAULT 'SINGLE'::text,
    cron text DEFAULT '* * * * *'::text NOT NULL,
    pgsnap_catalog_id integer,
    role_handling text DEFAULT 'USE_ROLE'::text,
    tblspc_handling text DEFAULT 'NO_TBLSPC'::text,
    date_added timestamp with time zone DEFAULT now(),
    CONSTRAINT pgsnap_restorejob_cron_check CHECK ((cron ~ '^([\*\/0-9,]+\ ){4}[\*\/0-9,]+$'::text)),
    CONSTRAINT pgsnap_restorejob_dest_dbname_check CHECK ((dest_dbname ~ '^[^".]*$'::text)),
    CONSTRAINT pgsnap_restorejob_existing_db_check CHECK ((existing_db = ANY (ARRAY['DROP'::text, 'RENAME'::text, 'DROP_BEFORE'::text]))),
    CONSTRAINT pgsnap_restorejob_jobtype_check CHECK ((jobtype = ANY (ARRAY['SINGLE'::text, 'REPEAT'::text, 'TRIGGER'::text]))),
    CONSTRAINT pgsnap_restorejob_restoreschema_check CHECK ((restoreschema ~ '^[^".]*$'::text)),
    CONSTRAINT pgsnap_restorejob_restoretype_check CHECK ((restoretype = ANY (ARRAY['FULL'::text, 'DATA'::text, 'SCHEMA'::text]))),
    CONSTRAINT pgsnap_restorejob_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


--
-- Name: mgr_restorejob; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW mgr_restorejob AS
 SELECT j.id,
    ((p.dns_name || ':'::text) || p.pgport) AS pgsql_instance,
    j.dest_dbname,
    j.restoreschema AS schema,
    j.restoretype AS type,
    j.restoreoptions AS options,
    j.jobtype,
    j.cron,
    j.status,
    j.comment,
    COALESCE(w.dns_name, '(trigger)'::text) AS pgs_worker
   FROM (((pgsnap_restorejob j
     JOIN pgsql_instance p ON ((p.id = j.dest_pgsql_instance_id)))
     LEFT JOIN pgsnap_catalog c ON ((c.id = j.pgsnap_catalog_id)))
     LEFT JOIN pgsnap_worker w ON ((w.id = c.bu_worker_id)));


--
-- Name: pgsnap_restorelog; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_restorelog (
    id integer NOT NULL,
    pgsnap_restorejob_id integer,
    starttime timestamp with time zone DEFAULT now(),
    endtime timestamp with time zone,
    status text DEFAULT 'RUNNING'::text,
    bu_path text,
    message text,
    bu_worker_id integer,
    pgsql_dns_name text,
    pgsql_port integer,
    dest_dbname text,
    restoreschema text,
    restoretype text
);


--
-- Name: mgr_restorelog; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW mgr_restorelog AS
 SELECT pgsnap_restorelog.id,
    ((pgsnap_restorelog.pgsql_dns_name || ':'::text) || pgsnap_restorelog.pgsql_port) AS pgsql_instance,
    ((((pgsnap_restorelog.pgsnap_restorejob_id || '/'::text) || pgsnap_restorelog.dest_dbname) || '.'::text) || pgsnap_restorelog.restoreschema) AS jobid_dbname,
    pgsnap_restorelog.restoretype,
    to_char(pgsnap_restorelog.starttime, 'YYYY-MM-DD HH24:MI:SS'::text) AS starttime,
    (pgsnap_restorelog.endtime - pgsnap_restorelog.starttime) AS duration,
    pgsnap_restorelog.status,
    substr(pgsnap_restorelog.message, 1, 32) AS message,
    w.dns_name
   FROM (pgsnap_restorelog
     LEFT JOIN pgsnap_worker w ON ((w.id = pgsnap_restorelog.bu_worker_id)));


--
-- Name: mgr_worker; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW mgr_worker AS
 SELECT pgsnap_worker.id,
    pgsnap_worker.dns_name,
    pgsnap_worker.status,
    pgsnap_worker.cron_cacheconfig,
    pgsnap_worker.cron_singlejob,
    pgsnap_worker.cron_clean,
    pgsnap_worker.cron_upload,
    pgsnap_worker.comment,
    to_char(pgsnap_worker.date_added, 'YYYY-MM-DD HH24:MI:SS'::text) AS date_added
   FROM pgsnap_worker
  ORDER BY pgsnap_worker.dns_name;


--
-- Name: pgsnap_catalog_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsnap_catalog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsnap_catalog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsnap_catalog_id_seq OWNED BY pgsnap_catalog.id;


--
-- Name: pgsnap_default; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_default (
    id integer NOT NULL,
    key text,
    value text
);


--
-- Name: pgsnap_default_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsnap_default_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsnap_default_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsnap_default_id_seq OWNED BY pgsnap_default.id;


--
-- Name: pgsnap_dumpjob_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsnap_dumpjob_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsnap_dumpjob_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsnap_dumpjob_id_seq OWNED BY pgsnap_dumpjob.id;


--
-- Name: pgsnap_message_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsnap_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsnap_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsnap_message_id_seq OWNED BY pgsnap_message.id;


--
-- Name: pgsnap_restorejob_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsnap_restorejob_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsnap_restorejob_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsnap_restorejob_id_seq OWNED BY pgsnap_restorejob.id;


--
-- Name: pgsnap_restorelog_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsnap_restorelog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsnap_restorelog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsnap_restorelog_id_seq OWNED BY pgsnap_restorelog.id;


--
-- Name: pgsnap_script; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_script (
    id integer NOT NULL,
    scriptname text,
    scriptcode text,
    date_added timestamp with time zone DEFAULT now()
);


--
-- Name: pgsnap_script_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsnap_script_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsnap_script_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsnap_script_id_seq OWNED BY pgsnap_script.id;


--
-- Name: pgsnap_worker_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsnap_worker_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsnap_worker_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsnap_worker_id_seq OWNED BY pgsnap_worker.id;


--
-- Name: pgsql_instance_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsql_instance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsql_instance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsql_instance_id_seq OWNED BY pgsql_instance.id;


--
-- Name: restorejob_compact; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW restorejob_compact AS
 SELECT j.id,
    w.dns_name AS pgs_worker,
    ((p.dns_name || ':'::text) || p.pgport) AS pgsql_instance,
    j.dest_dbname,
    j.restoretype,
    j.restoreschema,
    j.restoreoptions,
    j.cron,
    j.comment
   FROM (((pgsnap_restorejob j
     JOIN pgsql_instance p ON ((p.id = j.dest_pgsql_instance_id)))
     LEFT JOIN pgsnap_catalog c ON ((c.id = j.pgsnap_catalog_id)))
     LEFT JOIN pgsnap_worker w ON ((w.id = c.bu_worker_id)));


--
-- Name: vw_instance; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW vw_instance AS
 SELECT pgsql_instance.id,
    pgsql_instance.dns_name,
    pgsql_instance.pgport,
    pgsql_instance.comment,
    pgsql_instance.pgsql_superuser,
    pgsql_instance.status,
    pgsql_instance.bu_window_start,
    pgsql_instance.bu_window_end,
    pgsql_instance.pgsnap_worker_id_default AS pgsql_worker_id_default
   FROM pgsql_instance;


--
-- Name: vw_link_restore_catalog; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW vw_link_restore_catalog AS
 SELECT l.id AS restorelog_id,
    c.id AS catalog_id
   FROM (pgsnap_restorelog l
     JOIN pgsnap_catalog c ON ((((c.bu_location || '/'::text) || c.bu_name) = l.bu_path)));


--
-- Name: vw_pgsql_instance_bu_window_length; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW vw_pgsql_instance_bu_window_length AS
 SELECT pgsql_instance.id,
    pgsql_instance.bu_window_start AS start_hour,
    ((date_part('hour'::text, (((('20000102T'::text || pgsql_instance.bu_window_end) || ':00'::text))::timestamp with time zone - ((('20000101T'::text || pgsql_instance.bu_window_start) || ':00'::text))::timestamp with time zone)))::integer * 60) AS length_min
   FROM pgsql_instance;


--
-- Name: vw_restorejob_instance; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW vw_restorejob_instance AS
 SELECT r.id,
    r.pgsnap_catalog_id,
    r.dest_dbname,
    r.restoretype,
        CASE
            WHEN (r.restoreschema ~ '^[\*_0-9a-z]+$'::text) THEN r.restoreschema
            ELSE (('"'::text || r.restoreschema) || '"'::text)
        END AS restoreschema,
    r.restoreoptions,
    r.existing_db,
    r.cron,
    r.status AS status_restorejob,
    r.comment,
    r.jobtype,
    p.dns_name,
    p.pgport,
    p.pgsql_superuser,
    r.role_handling,
    r.tblspc_handling,
    p.status AS status_pgsqlinstance
   FROM (pgsnap_restorejob r
     JOIN pgsql_instance p ON ((r.dest_pgsql_instance_id = p.id)));


--
-- Name: vw_worker; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW vw_worker AS
 SELECT pgsnap_worker.id,
    pgsnap_worker.dns_name,
    pgsnap_worker.comment,
    pgsnap_worker.cron_cacheconfig,
    pgsnap_worker.cron_singlejob,
    pgsnap_worker.cron_clean,
    pgsnap_worker.cron_upload
   FROM pgsnap_worker;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_catalog ALTER COLUMN id SET DEFAULT nextval('pgsnap_catalog_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_default ALTER COLUMN id SET DEFAULT nextval('pgsnap_default_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_dumpjob ALTER COLUMN id SET DEFAULT nextval('pgsnap_dumpjob_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_message ALTER COLUMN id SET DEFAULT nextval('pgsnap_message_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_restorejob ALTER COLUMN id SET DEFAULT nextval('pgsnap_restorejob_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_restorelog ALTER COLUMN id SET DEFAULT nextval('pgsnap_restorelog_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_script ALTER COLUMN id SET DEFAULT nextval('pgsnap_script_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_worker ALTER COLUMN id SET DEFAULT nextval('pgsnap_worker_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsql_instance ALTER COLUMN id SET DEFAULT nextval('pgsql_instance_id_seq'::regclass);


--
-- Name: pgsnap_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_catalog
    ADD CONSTRAINT pgsnap_catalog_pkey PRIMARY KEY (id);


--
-- Name: pgsnap_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_default
    ADD CONSTRAINT pgsnap_default_pkey PRIMARY KEY (id);


--
-- Name: pgsnap_dumpjob_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_dumpjob
    ADD CONSTRAINT pgsnap_dumpjob_pkey PRIMARY KEY (id);


--
-- Name: pgsnap_message_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_message
    ADD CONSTRAINT pgsnap_message_pkey PRIMARY KEY (id);


--
-- Name: pgsnap_restorejob_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_restorejob
    ADD CONSTRAINT pgsnap_restorejob_pkey PRIMARY KEY (id);


--
-- Name: pgsnap_restorelog_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_restorelog
    ADD CONSTRAINT pgsnap_restorelog_pkey PRIMARY KEY (id);


--
-- Name: pgsnap_script_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_script
    ADD CONSTRAINT pgsnap_script_pkey PRIMARY KEY (id);


--
-- Name: pgsnap_worker_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_worker
    ADD CONSTRAINT pgsnap_worker_pkey PRIMARY KEY (id);


--
-- Name: pgsql_instance_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsql_instance
    ADD CONSTRAINT pgsql_instance_pkey PRIMARY KEY (id);


--
-- Name: fki_pgsnap_catalog_pgsnap_worker; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_pgsnap_catalog_pgsnap_worker ON pgsnap_catalog USING btree (bu_worker_id);


--
-- Name: fki_pgsnap_dumpjob_pgsnap_worker; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_pgsnap_dumpjob_pgsnap_worker ON pgsnap_dumpjob USING btree (pgsnap_worker_id);


--
-- Name: fki_pgsnap_restorejob_pgsql_instance; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_pgsnap_restorejob_pgsql_instance ON pgsnap_restorejob USING btree (dest_pgsql_instance_id);


--
-- Name: pgsnap_default_key_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX pgsnap_default_key_idx ON pgsnap_default USING btree (key);


--
-- Name: pgsnap_script_scriptname_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX pgsnap_script_scriptname_idx ON pgsnap_script USING btree (scriptname);


--
-- Name: pgsnap_worker_dns_name_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX pgsnap_worker_dns_name_idx ON pgsnap_worker USING btree (dns_name);


--
-- Name: pgsql_instance_dns_name_pgport_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX pgsql_instance_dns_name_pgport_idx ON pgsql_instance USING btree (dns_name, pgport);


--
-- Name: insert_pgsnap_dumpjob; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER insert_pgsnap_dumpjob BEFORE INSERT ON pgsnap_dumpjob FOR EACH ROW EXECUTE PROCEDURE insert_dumpjob();


--
-- Name: fk_pgsnap_catalog_pgsnap_worker; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_catalog
    ADD CONSTRAINT fk_pgsnap_catalog_pgsnap_worker FOREIGN KEY (bu_worker_id) REFERENCES pgsnap_worker(id);


--
-- Name: fk_pgsnap_dumpjob_pgsnap_worker; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_dumpjob
    ADD CONSTRAINT fk_pgsnap_dumpjob_pgsnap_worker FOREIGN KEY (pgsnap_worker_id) REFERENCES pgsnap_worker(id);


--
-- Name: fk_pgsnap_dumpjob_pgsql_instance; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_dumpjob
    ADD CONSTRAINT fk_pgsnap_dumpjob_pgsql_instance FOREIGN KEY (pgsql_instance_id) REFERENCES pgsql_instance(id);


--
-- Name: fk_pgsnap_restorejob_pgsnap_catalog; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_restorejob
    ADD CONSTRAINT fk_pgsnap_restorejob_pgsnap_catalog FOREIGN KEY (pgsnap_catalog_id) REFERENCES pgsnap_catalog(id);


--
-- Name: fk_pgsnap_restorejob_pgsql_instance; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_restorejob
    ADD CONSTRAINT fk_pgsnap_restorejob_pgsql_instance FOREIGN KEY (dest_pgsql_instance_id) REFERENCES pgsql_instance(id);


--
-- Name: fk_pgsnap_restorelog_pgsnap_restorejob; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_restorelog
    ADD CONSTRAINT fk_pgsnap_restorelog_pgsnap_restorejob FOREIGN KEY (pgsnap_restorejob_id) REFERENCES pgsnap_restorejob(id);


--
-- Name: fk_pgsql_instance_pgsnap_worker; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsql_instance
    ADD CONSTRAINT fk_pgsql_instance_pgsnap_worker FOREIGN KEY (pgsnap_worker_id_default) REFERENCES pgsnap_worker(id);


--
-- PostgreSQL database dump complete
--

