--
-- PostgreSQL database dump
--

\restrict kdPbkTgHTKjDSIBe1NgFcmwgNT64gCn4MRFMsUGePO3JVfhhEpK79tI9j5r7aaS

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
-- Name: attributes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attributes (
    key character varying(100) NOT NULL,
    value_type character varying(20) NOT NULL,
    unit character varying(20),
    description text,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
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
    slug character varying(100) NOT NULL,
    name character varying(200) NOT NULL,
    vertical character varying(50),
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
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
-- Name: category_filter_schema; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_filter_schema (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    attribute_key character varying(100) NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    ui_component character varying(50),
    required boolean DEFAULT false NOT NULL,
    filter_mode character varying(50),
    rules_json json,
    applies_to_transaction_modes json
);


--
-- Name: category_filter_schema_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_filter_schema_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_filter_schema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_filter_schema_id_seq OWNED BY public.category_filter_schema.id;


--
-- Name: idempotency_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.idempotency_keys (
    id bigint NOT NULL,
    scope_type character varying(20) NOT NULL,
    scope_id character varying(100) NOT NULL,
    key character varying(255) NOT NULL,
    request_hash character varying(64) NOT NULL,
    response_json json NOT NULL,
    created_at timestamp(0) without time zone NOT NULL,
    expires_at timestamp(0) without time zone NOT NULL
);


--
-- Name: idempotency_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.idempotency_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: idempotency_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.idempotency_keys_id_seq OWNED BY public.idempotency_keys.id;


--
-- Name: listing_offers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listing_offers (
    id uuid NOT NULL,
    listing_id uuid NOT NULL,
    provider_tenant_id uuid NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    price_amount bigint NOT NULL,
    price_currency character varying(3) DEFAULT 'TRY'::character varying NOT NULL,
    billing_model character varying(20) DEFAULT 'one_time'::character varying NOT NULL,
    attributes_json json,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: listing_service_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listing_service_areas (
    id bigint NOT NULL,
    listing_id uuid NOT NULL,
    city character varying(120) NOT NULL,
    all_districts boolean DEFAULT false NOT NULL,
    districts_json json,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: listing_service_areas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.listing_service_areas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listing_service_areas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.listing_service_areas_id_seq OWNED BY public.listing_service_areas.id;


--
-- Name: listings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listings (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    world character varying(20) NOT NULL,
    title character varying(120) NOT NULL,
    description text,
    price_amount bigint,
    currency character varying(3) DEFAULT 'TRY'::character varying NOT NULL,
    status character varying(20) DEFAULT 'draft'::character varying NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    category_id bigint,
    transaction_modes_json json,
    attributes_json json,
    location_scope character varying(20),
    location_city character varying(120),
    location_district character varying(120),
    location_neighborhood character varying(120),
    location_street character varying(160),
    location_building_no character varying(50),
    location_door_no character varying(50),
    location_address_line text,
    location_lat numeric(10,7),
    location_lng numeric(10,7)
);


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
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid NOT NULL,
    listing_id uuid NOT NULL,
    seller_tenant_id uuid NOT NULL,
    buyer_user_id uuid,
    quantity integer DEFAULT 1 NOT NULL,
    status character varying(20) DEFAULT 'placed'::character varying NOT NULL,
    totals_json json,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: rentals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rentals (
    id uuid NOT NULL,
    listing_id uuid NOT NULL,
    renter_user_id uuid NOT NULL,
    provider_tenant_id uuid NOT NULL,
    start_at timestamp(0) without time zone NOT NULL,
    end_at timestamp(0) without time zone NOT NULL,
    status character varying(20) DEFAULT 'requested'::character varying NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    pricing_source character varying(20),
    price_amount integer,
    price_currency character varying(3),
    billing_model character varying(30)
);


--
-- Name: reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservations (
    id uuid NOT NULL,
    listing_id uuid NOT NULL,
    provider_tenant_id uuid NOT NULL,
    requester_user_id uuid,
    slot_start timestamp(0) without time zone NOT NULL,
    slot_end timestamp(0) without time zone NOT NULL,
    party_size integer NOT NULL,
    status character varying(20) DEFAULT 'requested'::character varying NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    offer_id uuid,
    pricing_source character varying(20),
    price_amount integer,
    price_currency character varying(3),
    billing_model character varying(30)
);


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
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: category_filter_schema id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_filter_schema ALTER COLUMN id SET DEFAULT nextval('public.category_filter_schema_id_seq'::regclass);


--
-- Name: idempotency_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_keys ALTER COLUMN id SET DEFAULT nextval('public.idempotency_keys_id_seq'::regclass);


--
-- Name: listing_service_areas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_service_areas ALTER COLUMN id SET DEFAULT nextval('public.listing_service_areas_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: attributes attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attributes
    ADD CONSTRAINT attributes_pkey PRIMARY KEY (key);


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
-- Name: category_filter_schema category_filter_schema_category_id_attribute_key_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_filter_schema
    ADD CONSTRAINT category_filter_schema_category_id_attribute_key_unique UNIQUE (category_id, attribute_key);


--
-- Name: category_filter_schema category_filter_schema_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_filter_schema
    ADD CONSTRAINT category_filter_schema_pkey PRIMARY KEY (id);


--
-- Name: idempotency_keys idempotency_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_keys
    ADD CONSTRAINT idempotency_keys_pkey PRIMARY KEY (id);


--
-- Name: idempotency_keys idempotency_scope_key_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_keys
    ADD CONSTRAINT idempotency_scope_key_unique UNIQUE (scope_type, scope_id, key);


--
-- Name: listing_offers listing_offers_listing_id_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_offers
    ADD CONSTRAINT listing_offers_listing_id_code_unique UNIQUE (listing_id, code);


--
-- Name: listing_offers listing_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_offers
    ADD CONSTRAINT listing_offers_pkey PRIMARY KEY (id);


--
-- Name: listing_service_areas listing_service_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_service_areas
    ADD CONSTRAINT listing_service_areas_pkey PRIMARY KEY (id);


--
-- Name: listings listings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT listings_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: rentals rentals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rentals_pkey PRIMARY KEY (id);


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
-- Name: attributes_value_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attributes_value_type_index ON public.attributes USING btree (value_type);


--
-- Name: categories_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_parent_id_index ON public.categories USING btree (parent_id);


--
-- Name: categories_sort_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_sort_order_index ON public.categories USING btree (sort_order);


--
-- Name: categories_vertical_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_vertical_status_index ON public.categories USING btree (vertical, status);


--
-- Name: category_filter_schema_category_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX category_filter_schema_category_id_status_index ON public.category_filter_schema USING btree (category_id, status);


--
-- Name: category_filter_schema_sort_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX category_filter_schema_sort_order_index ON public.category_filter_schema USING btree (sort_order);


--
-- Name: idempotency_keys_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idempotency_keys_expires_at_index ON public.idempotency_keys USING btree (expires_at);


--
-- Name: idempotency_keys_scope_type_scope_id_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idempotency_keys_scope_type_scope_id_key_index ON public.idempotency_keys USING btree (scope_type, scope_id, key);


--
-- Name: listing_offers_listing_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listing_offers_listing_id_status_index ON public.listing_offers USING btree (listing_id, status);


--
-- Name: listing_offers_provider_tenant_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listing_offers_provider_tenant_id_status_index ON public.listing_offers USING btree (provider_tenant_id, status);


--
-- Name: listings_category_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listings_category_id_status_index ON public.listings USING btree (category_id, status);


--
-- Name: listings_location_city_district_neighborhood_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listings_location_city_district_neighborhood_index ON public.listings USING btree (location_city, location_district, location_neighborhood);


--
-- Name: listings_location_city_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listings_location_city_status_index ON public.listings USING btree (location_city, status);


--
-- Name: listings_location_lat_lng_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listings_location_lat_lng_index ON public.listings USING btree (location_lat, location_lng);


--
-- Name: listings_location_scope_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listings_location_scope_status_index ON public.listings USING btree (location_scope, status);


--
-- Name: listings_tenant_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listings_tenant_id_status_index ON public.listings USING btree (tenant_id, status);


--
-- Name: listings_tenant_id_world_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listings_tenant_id_world_status_index ON public.listings USING btree (tenant_id, world, status);


--
-- Name: listings_title_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listings_title_index ON public.listings USING btree (title);


--
-- Name: listings_world_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX listings_world_status_index ON public.listings USING btree (world, status);


--
-- Name: lsa_city_all_districts_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lsa_city_all_districts_index ON public.listing_service_areas USING btree (city, all_districts);


--
-- Name: lsa_listing_city_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lsa_listing_city_index ON public.listing_service_areas USING btree (listing_id, city);


--
-- Name: orders_buyer_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_buyer_user_id_index ON public.orders USING btree (buyer_user_id);


--
-- Name: orders_buyer_user_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_buyer_user_id_status_index ON public.orders USING btree (buyer_user_id, status);


--
-- Name: orders_listing_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_listing_id_index ON public.orders USING btree (listing_id);


--
-- Name: orders_seller_tenant_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_seller_tenant_id_index ON public.orders USING btree (seller_tenant_id);


--
-- Name: orders_seller_tenant_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_seller_tenant_id_status_index ON public.orders USING btree (seller_tenant_id, status);


--
-- Name: rentals_listing_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rentals_listing_id_index ON public.rentals USING btree (listing_id);


--
-- Name: rentals_listing_id_start_at_end_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rentals_listing_id_start_at_end_at_index ON public.rentals USING btree (listing_id, start_at, end_at);


--
-- Name: rentals_listing_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rentals_listing_id_status_index ON public.rentals USING btree (listing_id, status);


--
-- Name: rentals_provider_tenant_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rentals_provider_tenant_id_index ON public.rentals USING btree (provider_tenant_id);


--
-- Name: rentals_provider_tenant_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rentals_provider_tenant_id_status_index ON public.rentals USING btree (provider_tenant_id, status);


--
-- Name: rentals_renter_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rentals_renter_user_id_index ON public.rentals USING btree (renter_user_id);


--
-- Name: reservations_listing_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_listing_id_index ON public.reservations USING btree (listing_id);


--
-- Name: reservations_listing_id_slot_start_slot_end_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_listing_id_slot_start_slot_end_index ON public.reservations USING btree (listing_id, slot_start, slot_end);


--
-- Name: reservations_listing_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_listing_id_status_index ON public.reservations USING btree (listing_id, status);


--
-- Name: reservations_offer_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_offer_id_index ON public.reservations USING btree (offer_id);


--
-- Name: reservations_provider_tenant_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_provider_tenant_id_index ON public.reservations USING btree (provider_tenant_id);


--
-- Name: sessions_last_activity_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_last_activity_index ON public.sessions USING btree (last_activity);


--
-- Name: sessions_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_user_id_index ON public.sessions USING btree (user_id);


--
-- Name: categories categories_parent_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_foreign FOREIGN KEY (parent_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: category_filter_schema category_filter_schema_attribute_key_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_filter_schema
    ADD CONSTRAINT category_filter_schema_attribute_key_foreign FOREIGN KEY (attribute_key) REFERENCES public.attributes(key) ON DELETE CASCADE;


--
-- Name: category_filter_schema category_filter_schema_category_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_filter_schema
    ADD CONSTRAINT category_filter_schema_category_id_foreign FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: listing_offers listing_offers_listing_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_offers
    ADD CONSTRAINT listing_offers_listing_id_foreign FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE CASCADE;


--
-- Name: listing_service_areas listing_service_areas_listing_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_service_areas
    ADD CONSTRAINT listing_service_areas_listing_id_foreign FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE CASCADE;


--
-- Name: listings listings_category_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT listings_category_id_foreign FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: orders orders_listing_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_listing_id_foreign FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE CASCADE;


--
-- Name: rentals rentals_listing_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rentals_listing_id_foreign FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE CASCADE;


--
-- Name: reservations reservations_listing_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_listing_id_foreign FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE CASCADE;


--
-- Name: reservations reservations_offer_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_offer_id_foreign FOREIGN KEY (offer_id) REFERENCES public.listing_offers(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict kdPbkTgHTKjDSIBe1NgFcmwgNT64gCn4MRFMsUGePO3JVfhhEpK79tI9j5r7aaS

