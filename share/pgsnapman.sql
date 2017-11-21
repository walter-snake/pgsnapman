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


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: pgsnap_dumpjob; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_dumpjob (
    id integer NOT NULL,
    pgsnap_worker_id integer,
    pgsql_instance_id integer,
    dbname text,
    dumptype text DEFAULT 'FULL'::text,
    dumpschema text DEFAULT '*'::text,
    keep_daily integer DEFAULT 14,
    keep_weekly integer DEFAULT 2,
    keep_monthly integer DEFAULT 5,
    keep_yearly integer DEFAULT 2,
    comment text,
    cron text DEFAULT 'CRON'::text,
    status text DEFAULT 'ACTIVE'::text,
    jobtype text DEFAULT 'CRON'::text,
    pgsnap_restorejob_id integer DEFAULT (-1),
    CONSTRAINT pgsnap_dumpjob_jobtype_check CHECK ((jobtype = ANY (ARRAY['CRON'::text, 'SINGLE'::text]))),
    CONSTRAINT pgsnap_dumpjob_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


--
-- Name: pgsnap_worker; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pgsnap_worker (
    id integer NOT NULL,
    dns_name text,
    comment text,
    cron_cacheconfig text DEFAULT '15 20 * * *'::text,
    cron_singlejob text DEFAULT '* * * * *'::text,
    cron_clean text DEFAULT '15 18 * * *'::text,
    cron_upload text DEFAULT '*/5 * * * *'::text
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
    pgsql_worker_id_default integer,
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
    message text
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
    j.pgsnap_restorejob_id
   FROM ((pgsnap_dumpjob j
     JOIN pgsnap_worker b ON ((b.id = j.pgsnap_worker_id)))
     JOIN pgsql_instance p ON ((p.id = j.pgsql_instance_id)));


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
    pgsql_instance.pgsql_worker_id_default
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
-- Name: pgsnap_worker_dns_name_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX pgsnap_worker_dns_name_idx ON pgsnap_worker USING btree (dns_name);


--
-- Name: pgsql_instance_dns_name_pgport_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX pgsql_instance_dns_name_pgport_idx ON pgsql_instance USING btree (dns_name, pgport);


--
-- PostgreSQL database dump complete
--

