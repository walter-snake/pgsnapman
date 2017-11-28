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
-- Name: get_defaultworker(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_defaultworker(pgsqlinstance integer) RETURNS integer
    LANGUAGE sql
    AS $_$
select pgsnap_worker_id_default from pgsql_instance where id = $1;
$_$;


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
-- Name: get_keep_catjobid(timestamp without time zone, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_keep_catjobid(datenow timestamp without time zone, jobid integer, days integer, weeks integer, months integer, years integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
declare
  keep_slicestart timestamp without time zone;
  keep_sliceend timestamp without time zone;
  dj record;
  r record;
  keep_id record;
  keep_ids integer[];
begin

  -- initialize, end of first slice
  keep_sliceend := $1::date + ('1 day')::interval;

  -- 1 per day
  --raise notice 'Daily clean up, end date at start: %', keep_sliceend;
  for i in 1..days loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' days')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend)
        overlaps (starttime, starttime)
      and pgsnap_dumpjob_id = jobid
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
      where (keep_slicestart, keep_sliceend)
        overlaps (starttime, starttime)
      and pgsnap_dumpjob_id = jobid
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
      where (keep_slicestart, keep_sliceend)
        overlaps (starttime, starttime)
       and pgsnap_dumpjob_id = jobid
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
      where (keep_slicestart, keep_sliceend)
        overlaps (starttime, starttime)
      and pgsnap_dumpjob_id = jobid
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
  length := extract('hour' from (('20000102T' || pgsqldata.bu_window_end || ':00')::timestamp without time zone - ('20000101T' || pgsqldata.bu_window_start || ':00')::timestamp without time zone)::interval)::integer * 60;
  select (random() * length)::integer into rnd;
  select (pgsqldata.bu_window_start || ':00')::time + (rnd::text || ' min')::interval into crontime;
  return extract('min' from crontime) || ' ' || extract('hour' from crontime) || ' * * *' ;
end;
$$;


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
-- Name: put_dumpjob(integer, integer, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION put_dumpjob(pgsnapworkerid integer, pgsqlinstanceid integer, dbname text, schemaname text, comment text) RETURNS integer
    LANGUAGE sql
    AS $_$insert into pgsnap_dumpjob (pgsnap_worker_id, pgsql_instance_id, dbname, dumpschema, comment) values ($1, $2, $3, $4, $5) returning id;$_$;


--
-- Name: put_singlerun(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION put_singlerun(job_id integer, job_class text) RETURNS void
    LANGUAGE sql
    AS $_$INSERT INTO pgsnap_singlerun (jobid, jobclass) values ($1, $2);$_$;


--
-- Name: test_retention_keep(timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION test_retention_keep(datenow timestamp without time zone) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
declare
  days integer;
  weeks integer;
  months integer;
  years integer;
  keep_slicestart timestamp without time zone;
  keep_sliceend timestamp without time zone;
  dj record;
  r record;
  keep_id record;
  keep_ids integer[];
begin
  -- Get the clean up schedule from the dumpjobs table
  select * from pgsnap_dumpjob into dj where id = $1;
  days := dj.keep_daily;
  weeks := dj.keep_weekly;
  months := dj.keep_monthly;
  years := dj.keep_yearly;
  
  -- 1 per day older then 'keep slicestart' time
  keep_slicestart := $1::date;
  for i in 0..days - 1 loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_sliceend := keep_slicestart - (i + 1 || ' days')::interval;
    for r in select id
      from test_dates
      where (keep_slicestart - (i || ' days')::interval, keep_sliceend)
        overlaps (tijd, tijd)
      order by tijd desc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'day % %', i, r.id;
    end loop;
  end loop;
    
  -- 1 per week older then 'keep slicestart' time
  keep_slicestart := keep_sliceend;
  for i in 0..weeks - 1 loop
    -- using overlaps, we're going to collect all ids in week intervals for i-weeks, and then pick the oldest
    keep_sliceend := keep_slicestart - (i + 1 || ' weeks')::interval;
    for r in select id
      from test_dates
      where (keep_slicestart - (i || ' weeks')::interval, keep_sliceend)
        overlaps (tijd, tijd)
      order by tijd asc limit 1
   loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'week % %', i, r.id;
    end loop;
  end loop;

  -- 1 per month
  keep_slicestart := keep_sliceend;
  for i in 0..months - 1 loop
    -- using overlaps, we're going to collect all ids in week intervals for i-weeks, and then pick the oldest
    keep_sliceend := keep_slicestart - (i + 1 || ' months')::interval;
    for r in select id
      from test_dates
      where (keep_slicestart - (i || ' months')::interval, keep_sliceend)
        overlaps (tijd, tijd)
      order by tijd asc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'month % %', i, r.id;
    end loop;
  end loop;

  -- 1 per year
  keep_slicestart := keep_sliceend;
  for i in 0..years - 1 loop
    -- using overlaps, we're going to collect all ids in week intervals for i-weeks, and then pick the oldest
    keep_sliceend := keep_slicestart - (i + 1 || ' years')::interval;
    for r in select id
      from test_dates
      where (keep_slicestart - (i || ' years')::interval, keep_sliceend)
        overlaps (tijd, tijd)
      order by tijd asc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'year % %', i, r.id;
    end loop;
  end loop;

  -- output
  raise notice 'array size %', array_length(keep_ids, 1);
  for keep_id in select unnest(keep_ids)
  loop
    return next keep_id;
  end loop;
  return;
end;
$_$;


--
-- Name: test_retention_keep(timestamp without time zone, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION test_retention_keep(datenow timestamp without time zone, days integer, weeks integer, months integer, years integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
declare
  keep_slicestart timestamp without time zone;
  keep_sliceend timestamp without time zone;
  dj record;
  r record;
  keep_id record;
  keep_ids integer[];
begin

  -- initialize, end of first slice
  keep_sliceend := $1::date + ('1 day')::interval;

  -- 1 per day
  --raise notice 'Daily clean up, end date at start: %', keep_sliceend;
  for i in 1..days loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' days')::interval;
    for r in select id
      from test_dates
      where (keep_slicestart, keep_sliceend)
        overlaps (tijd, tijd)
      order by tijd desc limit 1
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
      from test_dates
      where (keep_slicestart, keep_sliceend)
        overlaps (tijd, tijd)
      order by tijd asc limit 1
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
      from test_dates
      where (keep_slicestart, keep_sliceend)
        overlaps (tijd, tijd)
      order by tijd asc limit 1
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
      from test_dates
      where (keep_slicestart, keep_sliceend)
        overlaps (tijd, tijd)
      order by tijd asc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'Y % % [%..%]', i, r.id, keep_slicestart, keep_sliceend;    
    end loop;
    -- set new slice end date
    keep_sliceend := keep_slicestart;
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


SET default_tablespace = '';

SET default_with_oids = false;

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
    jobtype text DEFAULT 'CRON'::text,
    pgsnap_restorejob_id integer DEFAULT (-1),
    date_added timestamp without time zone DEFAULT now(),
    CONSTRAINT pgsnap_dumpjob_dumptype_check CHECK ((dumptype = ANY (ARRAY['FULL'::text, 'SCHEMA'::text, 'CLUSTER_SCHEMA'::text, 'SCRIPT'::text]))),
    CONSTRAINT pgsnap_dumpjob_jobtype_check CHECK ((jobtype = ANY (ARRAY['CRON'::text, 'SINGLE'::text]))),
    CONSTRAINT pgsnap_dumpjob_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


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
    CONSTRAINT pgsnap_worker_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


--
-- Name: pgsql_instance; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsql_instance (
    id integer NOT NULL,
    dns_name text,
    pgport integer,
    comment text,
    pgsql_superuser text,
    status text DEFAULT 'ACTIVE'::text,
    bu_window_start integer DEFAULT 2,
    bu_window_end integer DEFAULT 6,
    pgsnap_worker_id_default integer,
    CONSTRAINT pgsql_instance_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


--
-- Name: old_stuff; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW old_stuff AS
 SELECT DISTINCT p.id,
    p.dns_name,
    p.pgport,
    p.comment,
    p.status,
    p.pgsql_superuser,
    b.id AS pgsnap_worker_id
   FROM ((pgsnap_dumpjob j
     JOIN pgsql_instance p ON ((p.id = j.pgsql_instance_id)))
     JOIN pgsnap_worker b ON ((j.pgsnap_worker_id = b.id)));


--
-- Name: pgsnap_catalog; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_catalog (
    id integer NOT NULL,
    pgsnap_dumpjob_id integer,
    starttime timestamp without time zone,
    endtime timestamp without time zone,
    status text,
    bu_name text,
    bu_location text,
    dbsize bigint,
    dumpsize bigint
);


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
-- Name: pgsnap_message; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_message (
    id integer NOT NULL,
    level text,
    pgsnap_tool text,
    logtime timestamp without time zone,
    message text,
    jobclass text,
    jobid integer
);


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
-- Name: pgsnap_restorejob; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_restorejob (
    id integer NOT NULL,
    pgsnap_dumpjob_id integer,
    dest_pgsql_instance_id integer,
    dest_dbname text,
    restoretype text DEFAULT 'FULL'::text,
    restoreschema text DEFAULT '*'::text,
    restoreoptions text DEFAULT ''::text,
    existing_db text DEFAULT 'RENAME'::text,
    cron text,
    status text DEFAULT 'ACTIVE'::text,
    comment text,
    jobtype text DEFAULT 'SINGLE'::text,
    CONSTRAINT pgsnap_restorejob_existing_db_check CHECK ((existing_db = ANY (ARRAY['DROP'::text, 'RENAME'::text]))),
    CONSTRAINT pgsnap_restorejob_jobtype_check CHECK ((jobtype = ANY (ARRAY['SINGLE'::text, 'CRON'::text, 'TRIGGER'::text]))),
    CONSTRAINT pgsnap_restorejob_restoretype_check CHECK ((restoretype = ANY (ARRAY['FULL'::text, 'DATA'::text, 'SCHEMA'::text]))),
    CONSTRAINT pgsnap_restorejob_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


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
-- Name: pgsnap_script; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_script (
    id integer NOT NULL,
    scriptname text,
    scriptcode text
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
-- Name: pgsnap_singlerun; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_singlerun (
    id integer NOT NULL,
    jobid integer NOT NULL,
    jobclass text NOT NULL,
    runtime timestamp without time zone DEFAULT now(),
    CONSTRAINT pgsnap_singlerun_jobclass_check CHECK ((jobclass = ANY (ARRAY['DUMP'::text, 'RESTORE'::text])))
);


--
-- Name: pgsnap_singlerun_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pgsnap_singlerun_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pgsnap_singlerun_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pgsnap_singlerun_id_seq OWNED BY pgsnap_singlerun.id;


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
-- Name: test_dates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE test_dates (
    id integer,
    tijd timestamp without time zone
);


--
-- Name: vw_catalog_compact; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW vw_catalog_compact AS
 SELECT p.dns_name,
    p.pgport,
    j.dbname,
    j.dumpschema,
    j.dumptype,
    c.bu_name,
    c.starttime,
    (c.endtime - c.starttime) AS duration,
    c.status,
    c.dbsize,
    c.dumpsize
   FROM ((pgsnap_catalog c
     JOIN pgsnap_dumpjob j ON ((j.id = c.pgsnap_dumpjob_id)))
     JOIN pgsql_instance p ON ((p.id = j.pgsql_instance_id)))
  ORDER BY c.starttime;


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
-- Name: vw_dumpjob_compact; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW vw_dumpjob_compact AS
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
-- Name: vw_pgsql_instance_bu_window_length; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW vw_pgsql_instance_bu_window_length AS
 SELECT pgsql_instance.id,
    pgsql_instance.bu_window_start AS start_hour,
    ((date_part('hour'::text, (((('20000102T'::text || pgsql_instance.bu_window_end) || ':00'::text))::timestamp without time zone - ((('20000101T'::text || pgsql_instance.bu_window_start) || ':00'::text))::timestamp without time zone)))::integer * 60) AS length_min
   FROM pgsql_instance;


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

ALTER TABLE ONLY pgsnap_script ALTER COLUMN id SET DEFAULT nextval('pgsnap_script_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pgsnap_singlerun ALTER COLUMN id SET DEFAULT nextval('pgsnap_singlerun_id_seq'::regclass);


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
-- Name: pgsnap_script_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_script
    ADD CONSTRAINT pgsnap_script_pkey PRIMARY KEY (id);


--
-- Name: pgsnap_singlerun_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pgsnap_singlerun
    ADD CONSTRAINT pgsnap_singlerun_pkey PRIMARY KEY (id);


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
-- Name: fki_pgsnap_dumpjob_pgsnap_worker; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_pgsnap_dumpjob_pgsnap_worker ON pgsnap_dumpjob USING btree (pgsnap_worker_id);


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
-- PostgreSQL database dump complete
--

