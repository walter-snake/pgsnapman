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
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: get_pgsnap_worker_id(text); Type: FUNCTION; Schema: public; Owner: wouterb
--

CREATE FUNCTION get_pgsnap_worker_id(dns_name text) RETURNS integer
    LANGUAGE sql
    AS $_$select id from pgsnap_worker where dns_name = $1;$_$;


ALTER FUNCTION public.get_pgsnap_worker_id(dns_name text) OWNER TO wouterb;

--
-- Name: get_pgsql_instance_id(text, integer); Type: FUNCTION; Schema: public; Owner: wouterb
--

CREATE FUNCTION get_pgsql_instance_id(dns_name text, pgport integer) RETURNS integer
    LANGUAGE sql
    AS $_$select id from pgsql_instance where dns_name = $1 and pgport = $2;$_$;


ALTER FUNCTION public.get_pgsql_instance_id(dns_name text, pgport integer) OWNER TO wouterb;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: pgsnap_worker; Type: TABLE; Schema: public; Owner: wouterb; Tablespace: 
--

CREATE TABLE pgsnap_worker (
    id integer NOT NULL,
    dns_name text,
    comment text
);


ALTER TABLE public.pgsnap_worker OWNER TO wouterb;

--
-- Name: backup_server_id_seq; Type: SEQUENCE; Schema: public; Owner: wouterb
--

CREATE SEQUENCE backup_server_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.backup_server_id_seq OWNER TO wouterb;

--
-- Name: backup_server_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouterb
--

ALTER SEQUENCE backup_server_id_seq OWNED BY pgsnap_worker.id;


--
-- Name: pgsnap_job; Type: TABLE; Schema: public; Owner: wouterb; Tablespace: 
--

CREATE TABLE pgsnap_job (
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
    CONSTRAINT db_dumpjob_jobtype_check CHECK ((jobtype = ANY (ARRAY['CRON'::text, 'SINGLE'::text]))),
    CONSTRAINT db_dumpjob_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


ALTER TABLE public.pgsnap_job OWNER TO wouterb;

--
-- Name: db_dumpjob_id_seq; Type: SEQUENCE; Schema: public; Owner: wouterb
--

CREATE SEQUENCE db_dumpjob_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.db_dumpjob_id_seq OWNER TO wouterb;

--
-- Name: db_dumpjob_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouterb
--

ALTER SEQUENCE db_dumpjob_id_seq OWNED BY pgsnap_job.id;


--
-- Name: pgsql_instance; Type: TABLE; Schema: public; Owner: wouterb; Tablespace: 
--

CREATE TABLE pgsql_instance (
    id integer NOT NULL,
    dns_name text,
    pgport integer,
    comment text,
    active boolean,
    pgsql_superuser text,
    status text DEFAULT 'ACTIVE'::text,
    CONSTRAINT ps_instance_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'HALTED'::text])))
);


ALTER TABLE public.pgsql_instance OWNER TO wouterb;

--
-- Name: pg_instance_id_seq; Type: SEQUENCE; Schema: public; Owner: wouterb
--

CREATE SEQUENCE pg_instance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pg_instance_id_seq OWNER TO wouterb;

--
-- Name: pg_instance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouterb
--

ALTER SEQUENCE pg_instance_id_seq OWNED BY pgsql_instance.id;


--
-- Name: pgsnap_catalog; Type: TABLE; Schema: public; Owner: wouterb; Tablespace: 
--

CREATE TABLE pgsnap_catalog (
    id integer NOT NULL,
    pgsnap_job_id integer,
    starttime timestamp without time zone,
    endtime timestamp without time zone,
    status text,
    bu_name text,
    bu_location text
);


ALTER TABLE public.pgsnap_catalog OWNER TO wouterb;

--
-- Name: pgsnap_catalog_id_seq; Type: SEQUENCE; Schema: public; Owner: wouterb
--

CREATE SEQUENCE pgsnap_catalog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pgsnap_catalog_id_seq OWNER TO wouterb;

--
-- Name: pgsnap_catalog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouterb
--

ALTER SEQUENCE pgsnap_catalog_id_seq OWNED BY pgsnap_catalog.id;


--
-- Name: vw_job_node_instance_old; Type: VIEW; Schema: public; Owner: wouterb
--

CREATE VIEW vw_job_node_instance_old AS
 SELECT j.id,
    j.pgsnap_worker_id AS bu_node_id,
    j.pgsql_instance_id AS ps_instance_id,
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
    b.dns_name AS bu_node_dns_name,
    p.dns_name AS ps_instance_dns_name,
    p.pgport AS ps_instance_pgport,
    p.pgsql_superuser AS ps_instance_superuser
   FROM ((pgsnap_job j
     JOIN pgsnap_worker b ON ((b.id = j.pgsnap_worker_id)))
     JOIN pgsql_instance p ON ((p.id = j.pgsql_instance_id)));


ALTER TABLE public.vw_job_node_instance_old OWNER TO wouterb;

--
-- Name: vw_job_worker_instance; Type: VIEW; Schema: public; Owner: wouterb
--

CREATE VIEW vw_job_worker_instance AS
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
    p.pgsql_superuser AS pgsql_instance_superuser
   FROM ((pgsnap_job j
     JOIN pgsnap_worker b ON ((b.id = j.pgsnap_worker_id)))
     JOIN pgsql_instance p ON ((p.id = j.pgsql_instance_id)));


ALTER TABLE public.vw_job_worker_instance OWNER TO wouterb;

--
-- Name: vw_node_instance_old; Type: VIEW; Schema: public; Owner: wouterb
--

CREATE VIEW vw_node_instance_old AS
 SELECT DISTINCT p.id,
    p.dns_name,
    p.pgport,
    p.comment,
    p.status,
    p.pgsql_superuser AS pgsuperuser,
    b.id AS bu_node_id
   FROM ((pgsnap_job j
     JOIN pgsql_instance p ON ((p.id = j.pgsql_instance_id)))
     JOIN pgsnap_worker b ON ((j.pgsnap_worker_id = b.id)));


ALTER TABLE public.vw_node_instance_old OWNER TO wouterb;

--
-- Name: vw_worker_instance; Type: VIEW; Schema: public; Owner: wouterb
--

CREATE VIEW vw_worker_instance AS
 SELECT DISTINCT p.id,
    p.dns_name,
    p.pgport,
    p.comment,
    p.status,
    p.pgsql_superuser,
    b.id AS pgsnap_worker_id
   FROM ((pgsnap_job j
     JOIN pgsql_instance p ON ((p.id = j.pgsql_instance_id)))
     JOIN pgsnap_worker b ON ((j.pgsnap_worker_id = b.id)));


ALTER TABLE public.vw_worker_instance OWNER TO wouterb;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouterb
--

ALTER TABLE ONLY pgsnap_catalog ALTER COLUMN id SET DEFAULT nextval('pgsnap_catalog_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouterb
--

ALTER TABLE ONLY pgsnap_job ALTER COLUMN id SET DEFAULT nextval('db_dumpjob_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouterb
--

ALTER TABLE ONLY pgsnap_worker ALTER COLUMN id SET DEFAULT nextval('backup_server_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouterb
--

ALTER TABLE ONLY pgsql_instance ALTER COLUMN id SET DEFAULT nextval('pg_instance_id_seq'::regclass);


--
-- Name: bu_node_pkey; Type: CONSTRAINT; Schema: public; Owner: wouterb; Tablespace: 
--

ALTER TABLE ONLY pgsnap_worker
    ADD CONSTRAINT bu_node_pkey PRIMARY KEY (id);


--
-- Name: db_dumpjob_pkey; Type: CONSTRAINT; Schema: public; Owner: wouterb; Tablespace: 
--

ALTER TABLE ONLY pgsnap_job
    ADD CONSTRAINT db_dumpjob_pkey PRIMARY KEY (id);


--
-- Name: ps_instance_pkey; Type: CONSTRAINT; Schema: public; Owner: wouterb; Tablespace: 
--

ALTER TABLE ONLY pgsql_instance
    ADD CONSTRAINT ps_instance_pkey PRIMARY KEY (id);


--
-- Name: bu_node_dns_name_idx; Type: INDEX; Schema: public; Owner: wouterb; Tablespace: 
--

CREATE UNIQUE INDEX bu_node_dns_name_idx ON pgsnap_worker USING btree (dns_name);


--
-- Name: ps_instance_dns_name_pgport_idx; Type: INDEX; Schema: public; Owner: wouterb; Tablespace: 
--

CREATE UNIQUE INDEX ps_instance_dns_name_pgport_idx ON pgsql_instance USING btree (dns_name, pgport);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

