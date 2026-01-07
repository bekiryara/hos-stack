--
-- PostgreSQL database dump
--

\restrict kInpuOIr6Yj6GLlKh62Kce4ZLJdLeaCl1Z0ATLtDsZZ2zkj0CDIE7nfQJmEZS6C

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

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
-- Name: api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying(255),
    token_hash character varying(255) NOT NULL,
    last_used_at timestamp(0) without time zone,
    expires_at timestamp(0) without time zone,
    created_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: api_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_tokens_id_seq OWNED BY public.api_tokens.id;


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id uuid NOT NULL,
    tenant_id bigint,
    actor_user_id bigint,
    action character varying(255) NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cache (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    expiration integer NOT NULL
);


--
-- Name: cache_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cache_locks (
    key character varying(255) NOT NULL,
    owner character varying(255) NOT NULL,
    expiration integer NOT NULL
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    parent_id bigint,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: category_product; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_product (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    product_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: category_product_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_product_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_product_id_seq OWNED BY public.category_product.id;


--
-- Name: failed_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.failed_jobs (
    id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    connection text NOT NULL,
    queue text NOT NULL,
    payload text NOT NULL,
    exception text NOT NULL,
    failed_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: failed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.failed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: failed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.failed_jobs_id_seq OWNED BY public.failed_jobs.id;


--
-- Name: guard_ledgers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guard_ledgers (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    user_id bigint,
    world character varying(32),
    subject_type character varying(255) NOT NULL,
    subject_id bigint NOT NULL,
    command_key character varying(160) NOT NULL,
    from_status character varying(255),
    to_status character varying(255) NOT NULL,
    from_version integer,
    to_version integer,
    created_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: guard_ledgers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guard_ledgers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guard_ledgers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guard_ledgers_id_seq OWNED BY public.guard_ledgers.id;


--
-- Name: hos_outbox_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hos_outbox_events (
    id bigint NOT NULL,
    tenant_id bigint,
    event_type character varying(255) NOT NULL,
    payload text NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    last_error text,
    available_at timestamp(0) without time zone,
    sent_at timestamp(0) without time zone,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: hos_outbox_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hos_outbox_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hos_outbox_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hos_outbox_events_id_seq OWNED BY public.hos_outbox_events.id;


--
-- Name: job_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_batches (
    id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    total_jobs integer NOT NULL,
    pending_jobs integer NOT NULL,
    failed_jobs integer NOT NULL,
    failed_job_ids text NOT NULL,
    options text,
    cancelled_at integer,
    created_at integer NOT NULL,
    finished_at integer
);


--
-- Name: jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jobs (
    id bigint NOT NULL,
    queue character varying(255) NOT NULL,
    payload text NOT NULL,
    attempts smallint NOT NULL,
    reserved_at integer,
    available_at integer NOT NULL,
    created_at integer NOT NULL
);


--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jobs_id_seq OWNED BY public.jobs.id;


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    migration character varying(255) NOT NULL,
    batch integer NOT NULL
);


--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    product_id bigint NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    line_total numeric(10,2) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    user_id bigint NOT NULL,
    total numeric(10,2) NOT NULL,
    status character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    entity_version integer DEFAULT 0 NOT NULL,
    CONSTRAINT orders_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'paid'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_reset_tokens (
    email character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    created_at timestamp(0) without time zone
);


--
-- Name: payment_webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_webhook_events (
    id bigint NOT NULL,
    provider character varying(255) NOT NULL,
    event_id character varying(255) NOT NULL,
    payload json NOT NULL,
    processed_at timestamp(0) without time zone,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: payment_webhook_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_webhook_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_webhook_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_webhook_events_id_seq OWNED BY public.payment_webhook_events.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    user_id bigint NOT NULL,
    payable_type character varying(255) NOT NULL,
    payable_id bigint NOT NULL,
    amount numeric(10,2) NOT NULL,
    status character varying(255) NOT NULL,
    provider character varying(255),
    provider_reference character varying(255),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    provider_payload json,
    entity_version integer DEFAULT 0 NOT NULL,
    CONSTRAINT payments_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'paid'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: product_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_images (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    url character varying(255) NOT NULL,
    alt character varying(255),
    sort_order integer DEFAULT 0 NOT NULL,
    is_cover boolean DEFAULT false NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: product_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_images_id_seq OWNED BY public.product_images.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    title character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    price numeric(10,2) NOT NULL,
    status character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    track_stock boolean DEFAULT false NOT NULL,
    stock_quantity integer,
    product_type character varying(255),
    rental_unit character varying(255),
    rental_min_units integer,
    rental_max_units integer,
    rental_step_units integer,
    instant_book boolean DEFAULT true NOT NULL,
    cancellation_policy character varying(255) DEFAULT 'flexible'::character varying NOT NULL,
    CONSTRAINT products_product_type_check CHECK (((product_type)::text = ANY ((ARRAY['sale'::character varying, 'rental'::character varying])::text[]))),
    CONSTRAINT products_rental_unit_check CHECK (((rental_unit)::text = ANY ((ARRAY['day'::character varying, 'hour'::character varying])::text[]))),
    CONSTRAINT products_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'passive'::character varying])::text[])))
);


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservations (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    user_id bigint NOT NULL,
    product_id bigint NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    total numeric(10,2) NOT NULL,
    status character varying(32) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    start_at timestamp(0) without time zone,
    end_at timestamp(0) without time zone,
    hold_expires_at timestamp(0) without time zone,
    entity_version integer DEFAULT 0 NOT NULL,
    CONSTRAINT reservations_status_check CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('confirmed'::character varying)::text, ('cancelled'::character varying)::text])))
);


--
-- Name: reservations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservations_id_seq OWNED BY public.reservations.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id character varying(255) NOT NULL,
    user_id bigint,
    ip_address character varying(45),
    user_agent text,
    payload text NOT NULL,
    last_activity integer NOT NULL
);


--
-- Name: status_change_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.status_change_logs (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    user_id bigint,
    source character varying(255) NOT NULL,
    subject_type character varying(255) NOT NULL,
    subject_id bigint NOT NULL,
    from_status character varying(255),
    to_status character varying(255) NOT NULL,
    created_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    note text
);


--
-- Name: status_change_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.status_change_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: status_change_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.status_change_logs_id_seq OWNED BY public.status_change_logs.id;


--
-- Name: tenant_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_users (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    CONSTRAINT tenant_users_role_check CHECK (((role)::text = ANY ((ARRAY['owner'::character varying, 'staff'::character varying])::text[])))
);


--
-- Name: tenant_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tenant_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tenant_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tenant_users_id_seq OWNED BY public.tenant_users.id;


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    owner_user_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: tenants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tenants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tenants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tenants_id_seq OWNED BY public.tenants.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    email_verified_at timestamp(0) without time zone,
    password character varying(255),
    remember_token character varying(100),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    is_super_admin boolean DEFAULT false NOT NULL,
    hos_user_id character varying(255)
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: api_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens ALTER COLUMN id SET DEFAULT nextval('public.api_tokens_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: category_product id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_product ALTER COLUMN id SET DEFAULT nextval('public.category_product_id_seq'::regclass);


--
-- Name: failed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.failed_jobs ALTER COLUMN id SET DEFAULT nextval('public.failed_jobs_id_seq'::regclass);


--
-- Name: guard_ledgers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guard_ledgers ALTER COLUMN id SET DEFAULT nextval('public.guard_ledgers_id_seq'::regclass);


--
-- Name: hos_outbox_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hos_outbox_events ALTER COLUMN id SET DEFAULT nextval('public.hos_outbox_events_id_seq'::regclass);


--
-- Name: jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs ALTER COLUMN id SET DEFAULT nextval('public.jobs_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: payment_webhook_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_webhook_events ALTER COLUMN id SET DEFAULT nextval('public.payment_webhook_events_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: product_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images ALTER COLUMN id SET DEFAULT nextval('public.product_images_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: reservations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations ALTER COLUMN id SET DEFAULT nextval('public.reservations_id_seq'::regclass);


--
-- Name: status_change_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_change_logs ALTER COLUMN id SET DEFAULT nextval('public.status_change_logs_id_seq'::regclass);


--
-- Name: tenant_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users ALTER COLUMN id SET DEFAULT nextval('public.tenant_users_id_seq'::regclass);


--
-- Name: tenants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants ALTER COLUMN id SET DEFAULT nextval('public.tenants_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: api_tokens api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_pkey PRIMARY KEY (id);


--
-- Name: api_tokens api_tokens_token_hash_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_token_hash_unique UNIQUE (token_hash);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: cache_locks cache_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cache_locks
    ADD CONSTRAINT cache_locks_pkey PRIMARY KEY (key);


--
-- Name: cache cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cache
    ADD CONSTRAINT cache_pkey PRIMARY KEY (key);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories categories_slug_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_slug_unique UNIQUE (slug);


--
-- Name: category_product category_product_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_product
    ADD CONSTRAINT category_product_pkey PRIMARY KEY (id);


--
-- Name: category_product category_product_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_product
    ADD CONSTRAINT category_product_unique UNIQUE (category_id, product_id);


--
-- Name: failed_jobs failed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_uuid_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_uuid_unique UNIQUE (uuid);


--
-- Name: guard_ledgers guard_ledgers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guard_ledgers
    ADD CONSTRAINT guard_ledgers_pkey PRIMARY KEY (id);


--
-- Name: guard_ledgers guard_ledgers_subject_command_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guard_ledgers
    ADD CONSTRAINT guard_ledgers_subject_command_unique UNIQUE (tenant_id, subject_type, subject_id, command_key);


--
-- Name: hos_outbox_events hos_outbox_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hos_outbox_events
    ADD CONSTRAINT hos_outbox_events_pkey PRIMARY KEY (id);


--
-- Name: job_batches job_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_batches
    ADD CONSTRAINT job_batches_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (email);


--
-- Name: payment_webhook_events payment_webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_webhook_events
    ADD CONSTRAINT payment_webhook_events_pkey PRIMARY KEY (id);


--
-- Name: payment_webhook_events payment_webhook_events_provider_event_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_webhook_events
    ADD CONSTRAINT payment_webhook_events_provider_event_id_unique UNIQUE (provider, event_id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: payments payments_provider_provider_reference_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_provider_provider_reference_unique UNIQUE (provider, provider_reference);


--
-- Name: product_images product_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: products products_tenant_id_slug_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_tenant_id_slug_unique UNIQUE (tenant_id, slug);


--
-- Name: reservations reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: status_change_logs status_change_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_change_logs
    ADD CONSTRAINT status_change_logs_pkey PRIMARY KEY (id);


--
-- Name: tenant_users tenant_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT tenant_users_pkey PRIMARY KEY (id);


--
-- Name: tenant_users tenant_users_tenant_id_user_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT tenant_users_tenant_id_user_id_unique UNIQUE (tenant_id, user_id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_slug_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_slug_unique UNIQUE (slug);


--
-- Name: users users_email_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_unique UNIQUE (email);


--
-- Name: users users_hos_user_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_hos_user_id_unique UNIQUE (hos_user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: audit_events_action_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_action_created_at_index ON public.audit_events USING btree (action, created_at);


--
-- Name: audit_events_action_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_action_index ON public.audit_events USING btree (action);


--
-- Name: audit_events_actor_user_id_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_actor_user_id_created_at_index ON public.audit_events USING btree (actor_user_id, created_at);


--
-- Name: audit_events_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_created_at_index ON public.audit_events USING btree (created_at);


--
-- Name: audit_events_tenant_id_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_tenant_id_created_at_index ON public.audit_events USING btree (tenant_id, created_at);


--
-- Name: categories_tree_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_tree_index ON public.categories USING btree (parent_id, is_active, sort_order);


--
-- Name: category_product_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX category_product_product_id_index ON public.category_product USING btree (product_id);


--
-- Name: guard_ledgers_subject_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX guard_ledgers_subject_index ON public.guard_ledgers USING btree (subject_type, subject_id);


--
-- Name: hos_outbox_events_available_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hos_outbox_events_available_at_index ON public.hos_outbox_events USING btree (available_at);


--
-- Name: hos_outbox_events_sent_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hos_outbox_events_sent_at_index ON public.hos_outbox_events USING btree (sent_at);


--
-- Name: hos_outbox_events_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hos_outbox_events_status_index ON public.hos_outbox_events USING btree (status);


--
-- Name: hos_outbox_events_tenant_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hos_outbox_events_tenant_id_index ON public.hos_outbox_events USING btree (tenant_id);


--
-- Name: jobs_queue_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX jobs_queue_index ON public.jobs USING btree (queue);


--
-- Name: order_items_order_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX order_items_order_id_index ON public.order_items USING btree (order_id);


--
-- Name: order_items_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX order_items_product_id_index ON public.order_items USING btree (product_id);


--
-- Name: orders_tenant_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_tenant_status_index ON public.orders USING btree (tenant_id, status);


--
-- Name: orders_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_user_id_index ON public.orders USING btree (user_id);


--
-- Name: payments_payable_type_payable_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payments_payable_type_payable_id_index ON public.payments USING btree (payable_type, payable_id);


--
-- Name: payments_tenant_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payments_tenant_status_index ON public.payments USING btree (tenant_id, status);


--
-- Name: payments_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payments_user_id_index ON public.payments USING btree (user_id);


--
-- Name: product_images_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_order_index ON public.product_images USING btree (product_id, is_cover, sort_order);


--
-- Name: products_tenant_rental_unit_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_tenant_rental_unit_index ON public.products USING btree (tenant_id, rental_unit);


--
-- Name: products_tenant_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_tenant_status_index ON public.products USING btree (tenant_id, status);


--
-- Name: products_tenant_type_cancel_policy_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_tenant_type_cancel_policy_index ON public.products USING btree (tenant_id, product_type, cancellation_policy);


--
-- Name: products_tenant_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_tenant_type_index ON public.products USING btree (tenant_id, product_type);


--
-- Name: products_tenant_type_instant_book_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_tenant_type_instant_book_index ON public.products USING btree (tenant_id, product_type, instant_book);


--
-- Name: reservations_hold_expire_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_hold_expire_index ON public.reservations USING btree (tenant_id, status, hold_expires_at);


--
-- Name: reservations_overlap_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_overlap_date_index ON public.reservations USING btree (tenant_id, product_id, status, start_date, end_date);


--
-- Name: reservations_overlap_datetime_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_overlap_datetime_index ON public.reservations USING btree (tenant_id, product_id, status, start_at, end_at);


--
-- Name: reservations_overlap_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_overlap_index ON public.reservations USING btree (product_id, status, start_date, end_date);


--
-- Name: reservations_tenant_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_tenant_status_index ON public.reservations USING btree (tenant_id, status);


--
-- Name: reservations_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_user_id_index ON public.reservations USING btree (user_id);


--
-- Name: sessions_last_activity_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_last_activity_index ON public.sessions USING btree (last_activity);


--
-- Name: sessions_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_user_id_index ON public.sessions USING btree (user_id);


--
-- Name: status_change_logs_subject_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX status_change_logs_subject_index ON public.status_change_logs USING btree (subject_type, subject_id);


--
-- Name: status_change_logs_tenant_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX status_change_logs_tenant_created_at_index ON public.status_change_logs USING btree (tenant_id, created_at);


--
-- Name: api_tokens api_tokens_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: audit_events audit_events_actor_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_actor_user_id_foreign FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: audit_events audit_events_tenant_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_tenant_id_foreign FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;


--
-- Name: categories categories_parent_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_foreign FOREIGN KEY (parent_id) REFERENCES public.categories(id);


--
-- Name: category_product category_product_category_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_product
    ADD CONSTRAINT category_product_category_id_foreign FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: category_product category_product_product_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_product
    ADD CONSTRAINT category_product_product_id_foreign FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: guard_ledgers guard_ledgers_tenant_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guard_ledgers
    ADD CONSTRAINT guard_ledgers_tenant_id_foreign FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: guard_ledgers guard_ledgers_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guard_ledgers
    ADD CONSTRAINT guard_ledgers_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: order_items order_items_order_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_foreign FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: order_items order_items_product_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_foreign FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: orders orders_tenant_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_tenant_id_foreign FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: orders orders_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: payments payments_tenant_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_tenant_id_foreign FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: payments payments_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: product_images product_images_product_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_product_id_foreign FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: products products_tenant_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_tenant_id_foreign FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: reservations reservations_product_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_product_id_foreign FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: reservations reservations_tenant_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_tenant_id_foreign FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: reservations reservations_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: status_change_logs status_change_logs_tenant_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_change_logs
    ADD CONSTRAINT status_change_logs_tenant_id_foreign FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: status_change_logs status_change_logs_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_change_logs
    ADD CONSTRAINT status_change_logs_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tenant_users tenant_users_tenant_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT tenant_users_tenant_id_foreign FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: tenant_users tenant_users_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT tenant_users_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tenants tenants_owner_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_owner_user_id_foreign FOREIGN KEY (owner_user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict kInpuOIr6Yj6GLlKh62Kce4ZLJdLeaCl1Z0ATLtDsZZ2zkj0CDIE7nfQJmEZS6C

