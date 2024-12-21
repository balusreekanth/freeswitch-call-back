--
-- PostgreSQL database dump
--

-- Dumped from database version 16.6 (Ubuntu 16.6-1.pgdg20.04+1)
-- Dumped by pg_dump version 16.6 (Ubuntu 16.6-1.pgdg20.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: v_busy_extensions; Type: TABLE; Schema: public; Owner: fusionpbx
--

CREATE TABLE IF NOT EXISTS public.v_busy_extensions (
    id integer NOT NULL,
    from_extension text,
    to_extension text,
    "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status text DEFAULT 'pending'::text,
    dialog_uuid text,
    domainname text
);


ALTER TABLE public.v_busy_extensions OWNER TO fusionpbx;

--
-- Name: v_busy_extensions_id_seq; Type: SEQUENCE; Schema: public; Owner: fusion pbx
--

CREATE SEQUENCE public.v_busy_extensions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.v_busy_extensions_id_seq OWNER TO fusionpbx;

--
-- Name: v_busy_extensions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owne r: fusionpbx
--

ALTER SEQUENCE public.v_busy_extensions_id_seq OWNED BY public.v_busy_extensions .id;


--
-- Name: v_busy_extensions id; Type: DEFAULT; Schema: public; Owner: fusionpbx
--

ALTER TABLE ONLY public.v_busy_extensions ALTER COLUMN id SET DEFAULT nextval('public.v_busy_extensions_id_seq'::regclass);


--
-- Name: v_busy_extensions v_busy_extensions_pkey; Type: CONSTRAINT; Schema: pub lic; Owner: fusionpbx
--

ALTER TABLE ONLY public.v_busy_extensions
    ADD CONSTRAINT v_busy_extensions_pkey PRIMARY KEY (id);


--
-- Name: idx_dialog_uuid; Type: INDEX; Schema: public; Owner: fusionpbx
--

CREATE UNIQUE INDEX idx_dialog_uuid ON public.v_busy_extensions USING btree (dialog_uuid);


--
-- PostgreSQL database dump complete
--

