--
-- PostgreSQL database dump
--

\restrict qinhTVVbXTKCVCXruK6cAaaANkZfDVy9slcc8ysDAqAG2PGJZSygKOkGihDrcqg

-- Dumped from database version 15.16 (Debian 15.16-1.pgdg13+1)
-- Dumped by pg_dump version 15.16 (Debian 15.16-1.pgdg13+1)

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

--
-- Name: pg_cron; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION pg_cron; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_cron IS 'Job scheduler for PostgreSQL';


--
-- Name: chat_attachment_type; Type: TYPE; Schema: public; Owner: klavier
--

CREATE TYPE public.chat_attachment_type AS ENUM (
    'image',
    'audio',
    'voice',
    'video',
    'file'
);


ALTER TYPE public.chat_attachment_type OWNER TO klavier;

--
-- Name: chat_message_state; Type: TYPE; Schema: public; Owner: klavier
--

CREATE TYPE public.chat_message_state AS ENUM (
    'sent',
    'delivered',
    'read'
);


ALTER TYPE public.chat_message_state OWNER TO klavier;

--
-- Name: feed_owner_type; Type: TYPE; Schema: public; Owner: klavier
--

CREATE TYPE public.feed_owner_type AS ENUM (
    'school',
    'teacher',
    'group'
);


ALTER TYPE public.feed_owner_type OWNER TO klavier;

--
-- Name: hometask_status; Type: TYPE; Schema: public; Owner: klavier
--

CREATE TYPE public.hometask_status AS ENUM (
    'assigned',
    'completed_by_student',
    'accomplished_by_teacher'
);


ALTER TYPE public.hometask_status OWNER TO klavier;

--
-- Name: hometask_type; Type: TYPE; Schema: public; Owner: klavier
--

CREATE TYPE public.hometask_type AS ENUM (
    'checklist',
    'progress',
    'simple',
    'free_answer'
);


ALTER TYPE public.hometask_type OWNER TO klavier;

--
-- Name: media_type; Type: TYPE; Schema: public; Owner: klavier
--

CREATE TYPE public.media_type AS ENUM (
    'image',
    'audio',
    'video',
    'file'
);


ALTER TYPE public.media_type OWNER TO klavier;

--
-- Name: role_status; Type: TYPE; Schema: public; Owner: klavier
--

CREATE TYPE public.role_status AS ENUM (
    'active',
    'archived'
);


ALTER TYPE public.role_status OWNER TO klavier;

--
-- Name: submission_type; Type: TYPE; Schema: public; Owner: klavier
--

CREATE TYPE public.submission_type AS ENUM (
    'photo',
    'text'
);


ALTER TYPE public.submission_type OWNER TO klavier;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: klavier
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO klavier;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: _sqlx_migrations; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public._sqlx_migrations (
    version bigint NOT NULL,
    description text NOT NULL,
    installed_on timestamp with time zone DEFAULT now() NOT NULL,
    success boolean NOT NULL,
    checksum bytea NOT NULL,
    execution_time bigint NOT NULL
);


ALTER TABLE public._sqlx_migrations OWNER TO klavier;

--
-- Name: chat_message_attachments; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.chat_message_attachments (
    id integer NOT NULL,
    message_id integer NOT NULL,
    media_id integer NOT NULL,
    attachment_type public.chat_attachment_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.chat_message_attachments OWNER TO klavier;

--
-- Name: chat_message_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.chat_message_attachments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chat_message_attachments_id_seq OWNER TO klavier;

--
-- Name: chat_message_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.chat_message_attachments_id_seq OWNED BY public.chat_message_attachments.id;


--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.chat_messages (
    id integer NOT NULL,
    thread_id integer NOT NULL,
    sender_id integer NOT NULL,
    body jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.chat_messages OWNER TO klavier;

--
-- Name: chat_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.chat_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chat_messages_id_seq OWNER TO klavier;

--
-- Name: chat_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.chat_messages_id_seq OWNED BY public.chat_messages.id;


--
-- Name: chat_presence; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.chat_presence (
    user_id integer NOT NULL,
    is_online boolean DEFAULT false NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.chat_presence OWNER TO klavier;

--
-- Name: chat_threads; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.chat_threads (
    id integer NOT NULL,
    participant_a_id integer NOT NULL,
    participant_b_id integer,
    is_admin_chat boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT admin_chat_no_participant_b CHECK ((((is_admin_chat = false) AND (participant_b_id IS NOT NULL)) OR ((is_admin_chat = true) AND (participant_b_id IS NULL)))),
    CONSTRAINT no_self_peer_chat CHECK (((is_admin_chat = true) OR (participant_a_id <> participant_b_id)))
);


ALTER TABLE public.chat_threads OWNER TO klavier;

--
-- Name: chat_threads_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.chat_threads_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chat_threads_id_seq OWNER TO klavier;

--
-- Name: chat_threads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.chat_threads_id_seq OWNED BY public.chat_threads.id;


--
-- Name: feed_comment_media; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.feed_comment_media (
    comment_id integer NOT NULL,
    media_id integer NOT NULL,
    attachment_type public.chat_attachment_type NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.feed_comment_media OWNER TO klavier;

--
-- Name: feed_comments; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.feed_comments (
    id integer NOT NULL,
    post_id integer NOT NULL,
    author_user_id integer NOT NULL,
    parent_comment_id integer,
    content jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.feed_comments OWNER TO klavier;

--
-- Name: feed_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.feed_comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.feed_comments_id_seq OWNER TO klavier;

--
-- Name: feed_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.feed_comments_id_seq OWNED BY public.feed_comments.id;


--
-- Name: feed_post_media; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.feed_post_media (
    post_id integer NOT NULL,
    media_id integer NOT NULL,
    attachment_type public.chat_attachment_type NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.feed_post_media OWNER TO klavier;

--
-- Name: feed_post_reads; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.feed_post_reads (
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    read_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.feed_post_reads OWNER TO klavier;

--
-- Name: feed_post_subscriptions; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.feed_post_subscriptions (
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    notify_on_comments boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.feed_post_subscriptions OWNER TO klavier;

--
-- Name: feed_posts; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.feed_posts (
    id integer NOT NULL,
    feed_id integer NOT NULL,
    author_user_id integer NOT NULL,
    title text,
    content jsonb NOT NULL,
    is_important boolean DEFAULT false NOT NULL,
    important_rank integer,
    allow_comments boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.feed_posts OWNER TO klavier;

--
-- Name: feed_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.feed_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.feed_posts_id_seq OWNER TO klavier;

--
-- Name: feed_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.feed_posts_id_seq OWNED BY public.feed_posts.id;


--
-- Name: feed_settings; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.feed_settings (
    feed_id integer NOT NULL,
    allow_student_posts boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.feed_settings OWNER TO klavier;

--
-- Name: feed_user_settings; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.feed_user_settings (
    feed_id integer NOT NULL,
    user_id integer NOT NULL,
    auto_subscribe_new_posts boolean DEFAULT true NOT NULL,
    notify_new_posts boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.feed_user_settings OWNER TO klavier;

--
-- Name: feeds; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.feeds (
    id integer NOT NULL,
    owner_type public.feed_owner_type NOT NULL,
    owner_user_id integer,
    title text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    owner_group_id integer,
    CONSTRAINT feeds_owner_scope_check CHECK (((((owner_type)::text = 'school'::text) AND (owner_user_id IS NULL) AND (owner_group_id IS NULL)) OR (((owner_type)::text = 'teacher'::text) AND (owner_group_id IS NULL)) OR (((owner_type)::text = 'group'::text) AND (owner_group_id IS NOT NULL) AND (owner_user_id IS NULL))))
);


ALTER TABLE public.feeds OWNER TO klavier;

--
-- Name: feeds_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.feeds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.feeds_id_seq OWNER TO klavier;

--
-- Name: feeds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.feeds_id_seq OWNED BY public.feeds.id;


--
-- Name: group_hometask_assignments; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.group_hometask_assignments (
    id integer NOT NULL,
    group_id integer NOT NULL,
    teacher_id integer NOT NULL,
    title text NOT NULL,
    description text,
    due_date timestamp with time zone,
    hometask_type public.hometask_type NOT NULL,
    repeat_every_days integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.group_hometask_assignments OWNER TO klavier;

--
-- Name: group_hometask_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.group_hometask_assignments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.group_hometask_assignments_id_seq OWNER TO klavier;

--
-- Name: group_hometask_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.group_hometask_assignments_id_seq OWNED BY public.group_hometask_assignments.id;


--
-- Name: group_student_relations; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.group_student_relations (
    group_id integer NOT NULL,
    student_user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.group_student_relations OWNER TO klavier;

--
-- Name: hometask_checklists; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.hometask_checklists (
    id integer NOT NULL,
    items jsonb NOT NULL
);


ALTER TABLE public.hometask_checklists OWNER TO klavier;

--
-- Name: hometask_checklists_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.hometask_checklists_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hometask_checklists_id_seq OWNER TO klavier;

--
-- Name: hometask_checklists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.hometask_checklists_id_seq OWNED BY public.hometask_checklists.id;


--
-- Name: hometask_submissions; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.hometask_submissions (
    id integer NOT NULL,
    hometask_id integer NOT NULL,
    student_id integer NOT NULL,
    submission_type public.submission_type NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.hometask_submissions OWNER TO klavier;

--
-- Name: hometask_submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.hometask_submissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hometask_submissions_id_seq OWNER TO klavier;

--
-- Name: hometask_submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.hometask_submissions_id_seq OWNED BY public.hometask_submissions.id;


--
-- Name: hometasks; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.hometasks (
    id integer NOT NULL,
    teacher_id integer NOT NULL,
    student_id integer NOT NULL,
    title text NOT NULL,
    description text,
    status public.hometask_status DEFAULT 'assigned'::public.hometask_status NOT NULL,
    due_date timestamp with time zone,
    repeat_every_days integer,
    next_reset_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    hometask_type public.hometask_type NOT NULL,
    content_id integer,
    group_assignment_id integer
);


ALTER TABLE public.hometasks OWNER TO klavier;

--
-- Name: hometasks_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.hometasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hometasks_id_seq OWNER TO klavier;

--
-- Name: hometasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.hometasks_id_seq OWNED BY public.hometasks.id;


--
-- Name: media_files; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.media_files (
    id integer NOT NULL,
    storage_key text NOT NULL,
    public_url text NOT NULL,
    media_type public.media_type NOT NULL,
    mime_type text NOT NULL,
    size_bytes integer NOT NULL,
    created_by_user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.media_files OWNER TO klavier;

--
-- Name: media_files_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.media_files_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.media_files_id_seq OWNER TO klavier;

--
-- Name: media_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.media_files_id_seq OWNED BY public.media_files.id;


--
-- Name: message_receipts; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.message_receipts (
    id integer NOT NULL,
    message_id integer NOT NULL,
    recipient_id integer NOT NULL,
    state public.chat_message_state DEFAULT 'sent'::public.chat_message_state NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.message_receipts OWNER TO klavier;

--
-- Name: message_receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.message_receipts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.message_receipts_id_seq OWNER TO klavier;

--
-- Name: message_receipts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.message_receipts_id_seq OWNED BY public.message_receipts.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    body jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    read_at timestamp with time zone,
    priority text DEFAULT 'normal'::text,
    CONSTRAINT notifications_priority_check CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text])))
);


ALTER TABLE public.notifications OWNER TO klavier;

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notifications_id_seq OWNER TO klavier;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: parent_student_relations; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.parent_student_relations (
    parent_user_id integer NOT NULL,
    student_user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT no_self_parenting CHECK ((parent_user_id <> student_user_id))
);


ALTER TABLE public.parent_student_relations OWNER TO klavier;

--
-- Name: parents; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.parents (
    user_id integer NOT NULL,
    status public.role_status DEFAULT 'active'::public.role_status NOT NULL,
    archived_at timestamp with time zone,
    archived_by integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.parents OWNER TO klavier;

--
-- Name: password_reset_requests; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.password_reset_requests (
    id integer NOT NULL,
    username text NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    resolved_by_admin_id integer
);


ALTER TABLE public.password_reset_requests OWNER TO klavier;

--
-- Name: password_reset_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.password_reset_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.password_reset_requests_id_seq OWNER TO klavier;

--
-- Name: password_reset_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.password_reset_requests_id_seq OWNED BY public.password_reset_requests.id;


--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.password_reset_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone
);


ALTER TABLE public.password_reset_tokens OWNER TO klavier;

--
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.password_reset_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.password_reset_tokens_id_seq OWNER TO klavier;

--
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.password_reset_tokens_id_seq OWNED BY public.password_reset_tokens.id;


--
-- Name: push_tokens; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.push_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token text NOT NULL,
    platform text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone
);


ALTER TABLE public.push_tokens OWNER TO klavier;

--
-- Name: push_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.push_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.push_tokens_id_seq OWNER TO klavier;

--
-- Name: push_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.push_tokens_id_seq OWNED BY public.push_tokens.id;


--
-- Name: registration_tokens; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.registration_tokens (
    id integer NOT NULL,
    token_hash text NOT NULL,
    created_by_user_id integer NOT NULL,
    role text NOT NULL,
    related_student_id integer,
    related_teacher_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    used_by_user_id integer,
    CONSTRAINT registration_tokens_role_check CHECK ((role = ANY (ARRAY['student'::text, 'parent'::text, 'teacher'::text])))
);


ALTER TABLE public.registration_tokens OWNER TO klavier;

--
-- Name: registration_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.registration_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.registration_tokens_id_seq OWNER TO klavier;

--
-- Name: registration_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.registration_tokens_id_seq OWNED BY public.registration_tokens.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.roles OWNER TO klavier;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.roles_id_seq OWNER TO klavier;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: student_groups; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.student_groups (
    id integer NOT NULL,
    teacher_user_id integer NOT NULL,
    name text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT student_groups_status_check CHECK ((status = ANY (ARRAY['active'::text, 'archived'::text])))
);


ALTER TABLE public.student_groups OWNER TO klavier;

--
-- Name: student_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.student_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.student_groups_id_seq OWNER TO klavier;

--
-- Name: student_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.student_groups_id_seq OWNED BY public.student_groups.id;


--
-- Name: students; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.students (
    user_id integer NOT NULL,
    birthday date NOT NULL,
    status public.role_status DEFAULT 'active'::public.role_status NOT NULL,
    archived_at timestamp with time zone,
    archived_by integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.students OWNER TO klavier;

--
-- Name: teacher_student_relations; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.teacher_student_relations (
    teacher_user_id integer NOT NULL,
    student_user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT no_self_teacher_student CHECK ((teacher_user_id <> student_user_id))
);


ALTER TABLE public.teacher_student_relations OWNER TO klavier;

--
-- Name: teachers; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.teachers (
    user_id integer NOT NULL,
    status public.role_status DEFAULT 'active'::public.role_status NOT NULL,
    archived_at timestamp with time zone,
    archived_by integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.teachers OWNER TO klavier;

--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.user_roles (
    user_id integer NOT NULL,
    role_id integer NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_roles OWNER TO klavier;

--
-- Name: users; Type: TABLE; Schema: public; Owner: klavier
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username text NOT NULL,
    full_name text NOT NULL,
    password_hash text NOT NULL,
    email text,
    phone text,
    profile_image text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.users OWNER TO klavier;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: klavier
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO klavier;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: klavier
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: chat_message_attachments id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_message_attachments ALTER COLUMN id SET DEFAULT nextval('public.chat_message_attachments_id_seq'::regclass);


--
-- Name: chat_messages id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_messages_id_seq'::regclass);


--
-- Name: chat_threads id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_threads ALTER COLUMN id SET DEFAULT nextval('public.chat_threads_id_seq'::regclass);


--
-- Name: feed_comments id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_comments ALTER COLUMN id SET DEFAULT nextval('public.feed_comments_id_seq'::regclass);


--
-- Name: feed_posts id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_posts ALTER COLUMN id SET DEFAULT nextval('public.feed_posts_id_seq'::regclass);


--
-- Name: feeds id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feeds ALTER COLUMN id SET DEFAULT nextval('public.feeds_id_seq'::regclass);


--
-- Name: group_hometask_assignments id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.group_hometask_assignments ALTER COLUMN id SET DEFAULT nextval('public.group_hometask_assignments_id_seq'::regclass);


--
-- Name: hometask_checklists id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometask_checklists ALTER COLUMN id SET DEFAULT nextval('public.hometask_checklists_id_seq'::regclass);


--
-- Name: hometask_submissions id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometask_submissions ALTER COLUMN id SET DEFAULT nextval('public.hometask_submissions_id_seq'::regclass);


--
-- Name: hometasks id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometasks ALTER COLUMN id SET DEFAULT nextval('public.hometasks_id_seq'::regclass);


--
-- Name: media_files id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.media_files ALTER COLUMN id SET DEFAULT nextval('public.media_files_id_seq'::regclass);


--
-- Name: message_receipts id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.message_receipts ALTER COLUMN id SET DEFAULT nextval('public.message_receipts_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: password_reset_requests id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.password_reset_requests ALTER COLUMN id SET DEFAULT nextval('public.password_reset_requests_id_seq'::regclass);


--
-- Name: password_reset_tokens id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.password_reset_tokens ALTER COLUMN id SET DEFAULT nextval('public.password_reset_tokens_id_seq'::regclass);


--
-- Name: push_tokens id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.push_tokens ALTER COLUMN id SET DEFAULT nextval('public.push_tokens_id_seq'::regclass);


--
-- Name: registration_tokens id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.registration_tokens ALTER COLUMN id SET DEFAULT nextval('public.registration_tokens_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: student_groups id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.student_groups ALTER COLUMN id SET DEFAULT nextval('public.student_groups_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: job; Type: TABLE DATA; Schema: cron; Owner: klavier
--

COPY cron.job (jobid, schedule, command, nodename, nodeport, database, username, active, jobname) FROM stdin;
1	0 */6 * * *	\n                DELETE FROM notifications\n                WHERE read_at IS NOT NULL\n                  AND read_at <= NOW() - INTERVAL '2 days'\n                                	localhost	5432	klavierdb	klavier	t	cleanup_read_notifications_older_than_2_days
\.


--
-- Data for Name: job_run_details; Type: TABLE DATA; Schema: cron; Owner: klavier
--

COPY cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) FROM stdin;
1	1	66	klavierdb	klavier	\n                DELETE FROM notifications\n                WHERE read_at IS NOT NULL\n                  AND read_at <= NOW() - INTERVAL '2 days'\n                                	succeeded	DELETE 112	2026-02-19 00:00:00.01151+00	2026-02-19 00:00:00.013688+00
1	2	293	klavierdb	klavier	\n                DELETE FROM notifications\n                WHERE read_at IS NOT NULL\n                  AND read_at <= NOW() - INTERVAL '2 days'\n                                	succeeded	DELETE 0	2026-02-19 06:00:00.01066+00	2026-02-19 06:00:00.011719+00
\.


--
-- Data for Name: _sqlx_migrations; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public._sqlx_migrations (version, description, installed_on, success, checksum, execution_time) FROM stdin;
20260209000000	create users table	2026-02-15 13:54:23.253121+00	t	\\x36362a212adee71e436c557ebdc5d27ab45ede832e4de7e91dcdf05df439a80c78f4d63b446c90556163260c9c21b09b	270647061
20260215000000	create push tokens	2026-02-15 20:57:13.013261+00	t	\\xade187ce7b78e11a82a93d07365dca7d066ad836dc7f7bec9f19cd91e991511cf274e946a3eb0b6427804f71f82cd3ca	27577130
20260218000000	add free answer hometask type	2026-02-18 23:36:12.124116+00	t	\\xcc78a2bf43c5628400ac8f10d09c9bfb33bc36797430a2a98141066110550e7b467eb8ff0c04bc57bb78f8eb1360c0a6	6236604
20260218010000	add student groups	2026-02-18 23:36:12.133051+00	t	\\xdc49c17ae54019748bb72062ca9565763c99892b7235566ca03728dc6ab793f70634ce90f5f2b553a27bd85c9f8e3c6e	50061594
20260219000000	add notification cleanup pg cron	2026-02-18 23:36:12.183818+00	t	\\xd9e945f45d63f6daeb93f2ad9317c3d01e4e29482c78aa9e3b69a6b6a35c6a0368f092148e1b4b78a655c7805586927e	51613278
\.


--
-- Data for Name: chat_message_attachments; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.chat_message_attachments (id, message_id, media_id, attachment_type, created_at) FROM stdin;
\.


--
-- Data for Name: chat_messages; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.chat_messages (id, thread_id, sender_id, body, created_at, updated_at) FROM stdin;
26	2	7	{"ops": [{"insert": "Test Test :)\\n"}]}	2026-02-16 06:13:59.018057+00	2026-02-16 06:13:59.018057+00
27	2	7	{"ops": [{"insert": "Arietta und Elegie gefallen mir, leider konnte ich nicht direkt bei den Hausaufgaben antworten.... \\n"}]}	2026-02-16 06:15:25.365962+00	2026-02-16 06:15:25.365962+00
28	3	8	{"ops": [{"insert": "Auch hier klappt es 🚨🎉👌🙏🎹\\n"}]}	2026-02-16 06:49:35.943251+00	2026-02-16 06:49:35.943251+00
29	2	1	{"ops": [{"insert": "Das wird ein nächster Schritt) \\n"}]}	2026-02-16 10:10:45.318108+00	2026-02-16 10:10:45.318108+00
30	2	1	{"ops": [{"insert": "Ja, beide sind ziemlich einfach, es wird a walk in the Park 😉\\n"}]}	2026-02-16 10:11:19.185504+00	2026-02-16 10:11:19.185504+00
31	2	7	{"ops": [{"insert": "Oder hast du andere Empfehlungen? \\n"}]}	2026-02-16 10:49:57.123729+00	2026-02-16 10:49:57.123729+00
32	2	1	{"ops": [{"insert": "Nein nein, macht sie, viele leichte sind oft besser\\n"}]}	2026-02-16 10:51:15.792556+00	2026-02-16 10:51:15.792556+00
33	2	7	{"ops": [{"insert": "Ok :)\\n"}]}	2026-02-16 11:07:43.064441+00	2026-02-16 11:07:43.064441+00
34	2	7	{"ops": [{"insert": "Vielleicht denke ich mir in beiden Tonarten noch zusätzlich eine Improvisation aus 😉 \\n"}]}	2026-02-16 14:01:15.868815+00	2026-02-16 14:01:15.868815+00
35	2	1	{"ops": [{"insert": "👍\\n"}]}	2026-02-16 15:39:31.218016+00	2026-02-16 15:39:31.218016+00
36	4	1	{"ops": [{"insert": "Не хотите ещё в пятницу прийти? У меня будет урок в 15:15, и потом около пяти, всё равно время свободное остаётся.\\n"}]}	2026-02-18 16:16:50.407378+00	2026-02-18 16:16:50.407378+00
37	5	1	{"ops": [{"insert": "Probably))\\n"}]}	2026-02-18 16:54:41.756384+00	2026-02-18 16:54:41.756384+00
38	5	44	{"ops": [{"insert": "Oh wow hello \\n"}]}	2026-02-18 16:56:18.607752+00	2026-02-18 16:56:18.607752+00
39	5	1	{"ops": [{"insert": "I've already forgotten, what I've given you as a home task…\\n"}]}	2026-02-18 16:56:33.751602+00	2026-02-18 16:56:33.751602+00
40	6	1	{"ops": [{"insert": "Dgh\\n"}]}	2026-02-18 17:09:55.952537+00	2026-02-18 17:09:55.952537+00
41	5	44	{"ops": [{"insert": "We didn’t say specifically what the homework is, but i think it is to continue playing the first page of waltz in a minor\\n"}]}	2026-02-18 17:14:54.492707+00	2026-02-18 17:14:54.492707+00
42	5	1	{"ops": [{"insert": "It looks, like I've broken the send message button the last time, I've touched the chat 🤦‍♂️\\nSo I'll still need to give a couple of bugfixes the next days 😁\\n"}]}	2026-02-18 17:29:29.143984+00	2026-02-18 17:29:29.143984+00
43	6	1	{"ops": [{"insert": "asdas\\n"}]}	2026-02-18 18:59:03.287774+00	2026-02-18 18:59:03.287774+00
44	6	1	{"ops": [{"insert": "asdas\\n"}]}	2026-02-18 18:59:36.48663+00	2026-02-18 18:59:36.48663+00
45	6	1	{"ops": [{"insert": "Fhhjf\\n"}]}	2026-02-18 19:00:13.473354+00	2026-02-18 19:00:13.473354+00
46	6	1	{"ops": [{"insert": "111\\n"}]}	2026-02-19 00:09:05.495677+00	2026-02-19 00:09:05.495677+00
47	6	1	{"ops": [{"insert": "Полав\\n"}]}	2026-02-19 01:59:06.525454+00	2026-02-19 01:59:06.525454+00
\.


--
-- Data for Name: chat_presence; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.chat_presence (user_id, is_online, last_seen_at) FROM stdin;
\.


--
-- Data for Name: chat_threads; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.chat_threads (id, participant_a_id, participant_b_id, is_admin_chat, created_at, updated_at) FROM stdin;
3	8	1	f	2026-02-16 06:49:19.466508+00	2026-02-16 06:49:35.94843+00
2	7	1	f	2026-02-16 06:13:50.658051+00	2026-02-16 15:39:31.222492+00
4	1	40	f	2026-02-18 16:16:03.173719+00	2026-02-18 16:16:50.411822+00
5	1	44	f	2026-02-18 16:54:35.065191+00	2026-02-18 17:29:29.148527+00
6	1	45	f	2026-02-18 17:09:52.282169+00	2026-02-19 01:59:06.530075+00
7	5	1	f	2026-02-19 02:53:50.690452+00	2026-02-19 02:53:50.690452+00
\.


--
-- Data for Name: feed_comment_media; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.feed_comment_media (comment_id, media_id, attachment_type, sort_order) FROM stdin;
\.


--
-- Data for Name: feed_comments; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.feed_comments (id, post_id, author_user_id, parent_comment_id, content, created_at, updated_at) FROM stdin;
1	3	1	\N	[{"insert": "test comment\\n"}]	2026-02-16 04:39:48.305892+00	2026-02-16 04:39:48.305892+00
2	4	1	\N	[{"insert": "Im jeden Fall, würde ich gerne am Montag als Probe im diesem Format unterrichten, ohne zusätzlichen Zahlungen. Können wir?\\n"}]	2026-02-19 11:35:40.662448+00	2026-02-19 11:35:40.662448+00
\.


--
-- Data for Name: feed_post_media; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.feed_post_media (post_id, media_id, attachment_type, sort_order) FROM stdin;
\.


--
-- Data for Name: feed_post_reads; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.feed_post_reads (post_id, user_id, read_at) FROM stdin;
2	1	2026-02-16 03:40:32.545698+00
1	1	2026-02-16 04:28:16.20749+00
3	31	2026-02-19 10:35:55.377566+00
4	1	2026-02-19 11:29:49.101679+00
3	5	2026-02-16 04:52:34.159436+00
4	33	2026-02-19 11:31:57.590733+00
3	47	2026-02-18 21:05:17.707491+00
3	39	2026-02-18 22:54:56.534922+00
4	34	2026-02-19 11:36:37.727392+00
4	19	2026-02-19 11:41:34.143176+00
3	1	2026-02-19 02:31:44.464222+00
1	5	2026-02-19 02:55:00.912978+00
\.


--
-- Data for Name: feed_post_subscriptions; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.feed_post_subscriptions (post_id, user_id, notify_on_comments, created_at) FROM stdin;
1	1	t	2026-02-16 03:35:55.173171+00
1	3	t	2026-02-16 03:35:55.173171+00
2	1	t	2026-02-16 03:40:32.545698+00
3	1	t	2026-02-16 03:44:09.584335+00
4	33	t	2026-02-19 11:31:59.081578+00
4	1	t	2026-02-19 00:07:33.827796+00
4	34	t	2026-02-19 11:36:39.321214+00
4	19	t	2026-02-19 11:37:58.152139+00
\.


--
-- Data for Name: feed_posts; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.feed_posts (id, feed_id, author_user_id, title, content, is_important, important_rank, allow_comments, created_at, updated_at) FROM stdin;
1	1	1	Willkomen!	[{"insert": "Liebe Freunde,", "attributes": {"bold": true}}, {"insert": "\\n", "attributes": {"align": "center"}}, {"insert": "wir möchten, dass ihr und eure Eltern immer über eure Hausaufgaben auf dem Laufenden seid,"}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "dass ihr die wichtigsten Informationen immer im Blick habt,"}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "dass ihr euch leicht mit Lehrern, der Verwaltung und Kollegen (wenn ihr Lehrer seid) in Verbindung setzen könnt,"}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "um euer Interesse am Unterricht zu wecken."}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "\\nDeshalb versuchen wir, diese App zu starten, in der bisher noch nicht einmal ein Viertel der Dinge umgesetzt ist, die wir uns vorgenommen haben.\\n\\nAber auf jeden Fall sieht sie schon besser aus als unsere Chats in WhatsApp, deshalb laden wir euch ein, mitzumachen!\\n\\nWenn Sie auf Fehler gestoßen sind, Ideen für die App haben oder Ihre Erfahrungen teilen möchten, schreiben Sie bitte an den Chat der Verwaltung!\\n\\nEinen schönen Tag noch!\\n"}]	t	\N	t	2026-02-16 03:35:55.173171+00	2026-02-16 03:35:55.173171+00
2	3	1	Notenbibliothek	[{"insert": "Ich habe vor, eine richtige Bibliothek aufzubauen, aber vorerst nutzen wir einen "}, {"insert": "Cloud-Ordner", "attributes": {"link": "https://disk.yandex.ru/d/mETfpC5je0xClw"}}, {"insert": ", den ich im Sommer zusammengestellt habe.\\nUnd die Website "}, {"insert": "imslp.org", "attributes": {"link": "https://imslp.org"}}, {"insert": " für Noten klassischer Musik\\n\\nWenn Ihnen ein Lied gefällt, suchen Sie es auf YouTube, dort finden Sie in der Regel auch einen Link zum Notenladen.\\n"}]	t	\N	t	2026-02-16 03:40:32.545698+00	2026-02-16 03:40:32.545698+00
3	3	1	Doppelunterrichte	[{"insert": "Im Januar habe ich festgestellt, dass ich etwa 10 Minuten brauche, um dem ersten Schüler eine Aufgabe zu geben, während der zweite Schüler in der Doppelstunde Zeit verliert.\\n\\nDeshalb schlage ich vor, alle unsere Doppelstunden "}, {"insert": "mit einer Überlappung von 15 Minuten zu versuchen", "attributes": {"bold": true}}, {"insert": ": In diesen 15 Minuten kann ich gut mit einem Schüler arbeiten und ihn dann für längere Zeit allein lassen, um mit dem zweiten Schüler zu beginnen. Lassen Sie uns überlegen, wie wir den Stundenplan am besten gestalten können.\\n"}]	f	\N	t	2026-02-16 03:44:09.584335+00	2026-02-16 03:44:09.584335+00
4	11	1	Wird die Gruppe gehen?	[{"insert": "Soweit ich verstanden habe, sind Sie grundsätzlich damit einverstanden, eine solche Gruppe zu organisieren, richtig?\\n\\nZunächst möchte ich noch einmal beschreiben, wie ich mir unseren Unterricht vorstelle:\\n30 Minuten lang üben wir mit Emmi Lilly und Mihn Ahn: wir singen, improvisieren, lernen Theorie usw."}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "30 Minuten geht Lilly zur Geige, während Emmy und Mihn Ahn in separaten Räumen arbeiten."}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "\\nIch bin sehr zufrieden mit der Entwicklung all unserer Gruppenaktivitäten, insbesondere mit einer ähnlichen Gruppe mit neuen Mädchen am Samstag. Wenn wir spezielle Zeiten für die gemeinsame musikalische Entwicklung haben, verbessern wir garantiert das allgemeine Musikverständnis, und die Kinder beginnen viel leichter, ihr Instrument zu spielen: Es fällt ihnen leichter zu lernen, Werke zu verstehen und sogar ihre Bewegungen zu koordinieren."}, {"insert": "\\n", "attributes": {"blockquote": true}}, {"insert": "Und in der Gruppe dieser Mädchen haben wir sogar die Möglichkeit, ein Ensemble aus zwei Pianistinnen und einer Geigerin zu bilden – das ist eine ganz besondere musikalische Erfahrung und eine Erfahrung der Zusammenarbeit!"}, {"insert": "\\n", "attributes": {"blockquote": true}}, {"insert": "\\nWenn ich richtig gerechnet habe, kostet das:"}, {"insert": "\\n", "attributes": {"header": 5}}, {"insert": "45 € pro Monat für die ersten 30 Minuten"}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "51 € pro Monat für die zweiten 30 Minuten für Mihn Ahn und Emmi, für Lilly bleibt der Violinunterricht ebenfalls bei 90 €"}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "\\nLetztendlich werden "}, {"insert": "alle Unterrichtsstunden", "attributes": {"font": "roboto-mono"}}, {"insert": " für die Mädchen der Familie Remus 231 € pro Monat kosten, derzeit zahlen Sie 180 €, wenn ich richtig gerechnet habe. Ich muss zugeben, dass das ein deutlicher Unterschied ist: Hier kommt gerade der Preis für den Gruppenunterricht für Lilly hinzu\\n\\nFür Mihn Ahn beträgt die Gebühr derzeit 90 €, wenn ich mich nicht irre, und wird 96 € betragen.\\n\\nZeitplan"}, {"insert": "\\n", "attributes": {"header": 5}}, {"insert": "Soweit ich weiß, sind wir hauptsächlich an Lillys Geigenunterricht um 17:00 Uhr gebunden."}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "Derzeit kommt Mihn Ahn nach den Mädchen um 17:30 Uhr."}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "\\nMeiner Meinung nach wäre es am einfachsten,\\num 17:00 Uhr mit dem Einzelunterricht für Emmi und Mihn Ahn zu beginnen, parallel zu Lillys Geigenunterricht,"}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "und um 17:30 Uhr mit dem Gruppenunterricht zu beginnen und um 18:00 Uhr zu enden."}, {"insert": "\\n", "attributes": {"list": "bullet"}}, {"insert": "\\nSind dieser Stundenplan und diese Preise für Sie in Ordnung?"}, {"insert": "\\n", "attributes": {"header": 5}}]	f	\N	t	2026-02-19 00:07:33.827796+00	2026-02-19 02:38:47.272127+00
\.


--
-- Data for Name: feed_settings; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.feed_settings (feed_id, allow_student_posts, created_at) FROM stdin;
2	f	2026-02-15 22:28:49.697592+00
12	t	2026-02-19 01:11:41.053959+00
1	f	2026-02-15 13:54:23.253121+00
3	f	2026-02-16 03:36:12.964092+00
11	t	2026-02-18 23:38:47.107355+00
\.


--
-- Data for Name: feed_user_settings; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.feed_user_settings (feed_id, user_id, auto_subscribe_new_posts, notify_new_posts, created_at) FROM stdin;
2	3	t	t	2026-02-15 22:28:49.792703+00
1	3	t	t	2026-02-15 22:28:55.796522+00
11	34	t	t	2026-02-19 11:36:34.407252+00
11	19	t	t	2026-02-19 11:37:46.999421+00
3	12	t	t	2026-02-16 06:56:26.508381+00
1	12	t	t	2026-02-16 06:56:34.20818+00
3	7	t	t	2026-02-16 06:15:59.847473+00
1	36	t	t	2026-02-18 15:24:01.102763+00
3	36	t	t	2026-02-18 15:24:52.927929+00
3	40	t	t	2026-02-18 15:35:34.600152+00
3	42	t	t	2026-02-18 15:48:40.193327+00
1	42	t	t	2026-02-18 15:50:18.516928+00
3	21	t	t	2026-02-18 16:23:47.244443+00
1	44	t	t	2026-02-18 16:51:40.196954+00
3	44	t	t	2026-02-18 16:51:48.343781+00
3	37	t	t	2026-02-18 18:14:10.454413+00
1	7	t	t	2026-02-16 06:15:32.098481+00
1	46	t	t	2026-02-18 20:26:29.171648+00
3	47	t	t	2026-02-18 21:04:00.30401+00
1	38	t	t	2026-02-18 20:57:13.33641+00
3	38	t	t	2026-02-18 15:26:31.28659+00
3	39	t	t	2026-02-18 15:31:18.017581+00
1	39	t	t	2026-02-18 15:49:39.70567+00
1	1	t	t	2026-02-16 00:07:05.53474+00
3	1	t	t	2026-02-16 03:36:13.039405+00
12	1	t	t	2026-02-19 01:11:41.14221+00
3	5	t	t	2026-02-16 04:52:31.941437+00
1	5	t	t	2026-02-19 02:54:52.222599+00
3	31	t	t	2026-02-19 10:35:37.59302+00
11	1	t	t	2026-02-18 23:38:47.18074+00
11	33	t	t	2026-02-19 11:27:20.558873+00
\.


--
-- Data for Name: feeds; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.feeds (id, owner_type, owner_user_id, title, created_at, owner_group_id) FROM stdin;
1	school	\N	School Feed	2026-02-15 13:54:23.253121+00	\N
2	teacher	3	Patrick Schulze Feed	2026-02-15 13:55:28.255152+00	\N
3	teacher	1	Timofei Kazantsev Feed	2026-02-15 14:43:34.657539+00	\N
4	teacher	13	Dimitri Bekdurdyew Feed	2026-02-17 20:38:04.468685+00	\N
5	teacher	14	Jevgenij Taruntsov Feed	2026-02-18 14:41:47.702572+00	\N
6	teacher	15	Lisa Schnejdar Feed	2026-02-18 14:42:48.695694+00	\N
7	teacher	\N	Tatjana Reis Feed	2026-02-18 14:43:53.819324+00	\N
8	teacher	17	Tatjana Reis Feed	2026-02-18 14:44:28.014162+00	\N
9	teacher	18	Larisa Nutzko Feed	2026-02-18 14:46:38.971028+00	\N
10	teacher	43	Constanze Bischoff Feed	2026-02-18 16:10:42.311972+00	\N
11	group	\N	Montags Mädchen Feed	2026-02-18 23:38:34.704954+00	1
12	group	\N	Gebruder Kunz Feed	2026-02-19 00:10:44.138419+00	2
\.


--
-- Data for Name: group_hometask_assignments; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.group_hometask_assignments (id, group_id, teacher_id, title, description, due_date, hometask_type, repeat_every_days, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: group_student_relations; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.group_student_relations (group_id, student_user_id, created_at) FROM stdin;
1	19	2026-02-18 23:38:34.704954+00
1	20	2026-02-18 23:38:34.704954+00
1	33	2026-02-18 23:38:34.704954+00
2	29	2026-02-19 00:10:44.138419+00
2	32	2026-02-19 00:10:44.138419+00
\.


--
-- Data for Name: hometask_checklists; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.hometask_checklists (id, items) FROM stdin;
1	[{"text": "Wie ein Musikalslied: interessant!", "is_done": false}, {"text": "Die Begleitung fängt an, 2 Takte, dann sie wiederholt und weiter spielt", "is_done": false}, {"text": "In der 2. Strofe ist Rechte Hand 1 Oktave höher", "is_done": false}]
2	[{"text": "Du bist die Begleitung, sie ‒ Melodie", "is_done": false}, {"text": "Und tauschen", "is_done": false}]
3	[{"text": "первая строчка", "is_done": false}, {"text": "4 такта во второй строчке", "is_done": false}, {"text": "ещё 4 такта во второй строчке", "is_done": false}]
4	[{"text": "In C-Dur (original)", "is_done": false}, {"text": "In G-dur (mit Fis statt F)", "is_done": false}, {"text": "In F-Dur (mit B statt H)", "is_done": false}]
9	[{"text": "вступление", "progress": 1}, {"text": "главная тема", "progress": 1}, {"text": "переход", "progress": 0}, {"text": "главная тема вальса", "progress": 0}, {"text": "контрастная тема", "progress": 0}, {"text": "первая кульминация", "progress": 0}, {"text": "кода основной части", "progress": 0}, {"text": "завершающая тема", "progress": 0}, {"text": "кода", "progress": 0}]
5	[{"text": "1. Phrase", "progress": 3}, {"text": "2. Phrase", "progress": 2}, {"text": "3. Phrase, Takte 1-2", "progress": 1}, {"text": "3. Phrase, Takte 3-4", "progress": 1}, {"text": "4. Phrase", "progress": 0}]
6	[{"text": "C-Dur", "is_done": false}, {"text": "G-Dur", "is_done": false}]
10	[]
7	[{"text": "The 1st phrase", "progress": 2}, {"text": "The 2nd phrase", "progress": 2}, {"text": "2nd part, bars 1-2", "progress": 2}, {"text": "2nd part, bars 3-4", "progress": 1}, {"text": "2nd part, bars 5-6", "progress": 1}, {"text": "2nd part, bars 7-9", "progress": 1}]
8	[{"text": "три ноты в левой, три ноты в правой: только белые клавиши, левая рука не играет от ноты си. Тоника - либо до, либо ля", "is_done": false}, {"text": "то же самое, но в соль мажоре: вместо фа - фа#, и от фа# левая рука не играет", "is_done": false}, {"text": "попробуй более свободную мелодию: не только три ноты, но больше как нравится", "is_done": false}]
\.


--
-- Data for Name: hometask_submissions; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.hometask_submissions (id, hometask_id, student_id, submission_type, content, created_at) FROM stdin;
\.


--
-- Data for Name: hometasks; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.hometasks (id, teacher_id, student_id, title, description, status, due_date, repeat_every_days, next_reset_at, created_at, updated_at, sort_order, hometask_type, content_id, group_assignment_id) FROM stdin;
7	1	5	Посмотри новую программу	Может быть, тебе что-то уже нравится? Или посмотри в папку с нотами для учеников	accomplished_by_teacher	\N	\N	\N	2026-02-16 04:09:00.323643+00	2026-02-18 03:10:54.056082+00	1	simple	\N	\N
8	1	19	Entscheiden, was du weiter spielen willst	\N	assigned	\N	\N	\N	2026-02-18 15:44:30.823143+00	2026-02-18 15:44:30.823143+00	1	simple	\N	\N
9	1	27	Учи болезнь куклы вместе с Ангелиной	Ты ‒ правую руку, Ангелина ‒ левую, потом ‒ наоборот\n\nВсе фрагменты по очереди	assigned	\N	\N	\N	2026-02-18 15:46:06.534249+00	2026-02-18 15:46:06.534249+00	1	checklist	3	\N
10	1	29	Foolow me spielen	\N	assigned	\N	2	2026-02-20 15:48:18.708205+00	2026-02-18 15:48:18.70632+00	2026-02-18 15:48:18.70632+00	1	checklist	4	\N
11	1	29	Den Rumänischen Tanz vertig zu machen	Macht Schritt-fur-Schritt: Linke Hand, Rechte Hand, beide, usw	assigned	\N	\N	\N	2026-02-18 15:53:40.708163+00	2026-02-18 15:53:40.708163+00	2	progress	5	\N
12	1	38	Denkt, was du weiter spielen willst	\N	assigned	\N	\N	\N	2026-02-18 15:56:11.400548+00	2026-02-18 15:56:11.400548+00	1	simple	\N	\N
13	1	40	Этюд	Левой рукой, с метрономом, хотя бы 5 раз. Можно 10!\nНадо ему помогать голосом, пока что в метроном попадать сложно, но надо этому научиться.	assigned	\N	\N	\N	2026-02-18 15:58:41.320025+00	2026-02-18 15:58:41.320025+00	1	simple	\N	\N
14	1	40	Follow Me	Для каждой тональности мы написали на обратной стороне свои гармонии	assigned	\N	\N	\N	2026-02-18 15:59:27.592378+00	2026-02-18 15:59:27.592378+00	2	checklist	6	\N
15	1	40	Попробуй поиграть что-то своё	Что-то похожее на Follow me: трезвучие в левой → трезвучие в правой. Пользуйся домиком с тональной семьёй	assigned	\N	\N	\N	2026-02-18 16:00:46.49981+00	2026-02-18 16:00:46.49981+00	3	simple	\N	\N
16	1	42	Denkt weiter am Programm.	• Prokofiev's Sonata 3.Satz ist noch immer gut Wahl.\n• Rachmaninow op.23 №5 ist möglich\n• deine Wünsche	assigned	\N	\N	\N	2026-02-18 16:02:04.322486+00	2026-02-18 16:02:04.322486+00	1	simple	\N	\N
17	1	44	Valse	{"ops":[{"insert":"I think, you still need to concentrate on little parts: 1-2 bars and master each one, until you're free with playing it. Then repeat them 2-3 more times for making sure 😉\\nAnd play the whole page 1-2 times in day\\n"}]}	assigned	\N	\N	\N	2026-02-18 17:28:13.686573+00	2026-02-19 01:51:59.518506+00	1	progress	7	\N
18	1	5	Импровизируй	{"ops":[{"insert":"От простого к сложному: самое главное, старайся придерживаться правил.\\n"}]}	assigned	\N	1	2026-02-20 02:25:53.900878+00	2026-02-19 02:25:53.897656+00	2026-02-19 02:25:53.897656+00	2	checklist	8	\N
19	1	5	ходячий замок	{"ops":[{"insert":"Грызи потихоньку\\n"}]}	assigned	\N	\N	\N	2026-02-19 02:28:44.883828+00	2026-02-19 02:29:25.826461+00	3	progress	9	\N
20	1	5	hollow Knight	{"ops":[{"insert":"Взять папу и сделать вместе ноты (лучше в школе)\\n"}]}	assigned	\N	\N	\N	2026-02-19 02:30:13.543698+00	2026-02-19 02:30:13.543698+00	4	simple	\N	\N
21	1	27	подумай, что ты сама хочешь играть	{"ops":[{"insert":"Любая музыка, главное - чтобы тебе нравилась \\n"}]}	assigned	\N	\N	\N	2026-02-19 02:59:04.159623+00	2026-02-19 02:59:04.159623+00	2	free_answer	10	\N
4	1	8	Häschen Klein	Mit Mama spielen: oder die Melodie, oder die Begleitung	assigned	\N	\N	\N	2026-02-16 04:05:51.965368+00	2026-02-16 04:05:51.965368+00	1	checklist	1	\N
5	1	9	Denkt an dem Program	Du kannst oder in unserem Ordner nachsuchen, oder etwas anderes mitbringen!	assigned	\N	\N	\N	2026-02-16 04:06:33.777039+00	2026-02-16 04:06:33.777039+00	1	simple	\N	\N
6	1	10	Probiert mit Anna Martha Improvisieren, Ihr habt das nicht schlecht gemacht!	\N	assigned	\N	\N	\N	2026-02-16 04:08:02.871158+00	2026-02-16 04:08:02.871158+00	1	checklist	2	\N
3	1	7	Das neue Programm finden	Vergisst mir nicht zu schreiben, was von Grieg dir gefählt)	accomplished_by_teacher	\N	\N	\N	2026-02-16 04:03:12.626516+00	2026-02-16 10:11:32.178738+00	1	simple	\N	\N
\.


--
-- Data for Name: media_files; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.media_files (id, storage_key, public_url, media_type, mime_type, size_bytes, created_by_user_id, created_at) FROM stdin;
\.


--
-- Data for Name: message_receipts; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.message_receipts (id, message_id, recipient_id, state, updated_at) FROM stdin;
32	32	7	read	2026-02-18 15:42:47.273051+00
35	35	7	read	2026-02-18 15:42:47.274211+00
30	30	7	read	2026-02-18 15:42:47.340501+00
29	29	7	read	2026-02-18 15:43:03.383682+00
36	36	40	sent	2026-02-18 16:16:50.409887+00
40	40	45	sent	2026-02-18 17:09:55.955303+00
39	39	44	read	2026-02-18 17:15:09.30501+00
37	37	44	read	2026-02-18 17:15:09.306163+00
42	42	44	sent	2026-02-18 17:29:29.146747+00
43	43	45	sent	2026-02-18 18:59:03.290616+00
44	44	45	sent	2026-02-18 18:59:36.489173+00
45	45	45	sent	2026-02-18 19:00:13.474771+00
46	46	45	sent	2026-02-19 00:09:05.4986+00
34	34	1	read	2026-02-19 01:00:45.184158+00
33	33	1	read	2026-02-19 01:00:45.24844+00
31	31	1	read	2026-02-19 01:04:22.728594+00
27	27	1	read	2026-02-19 01:35:38.048164+00
26	26	1	read	2026-02-19 01:35:38.05461+00
28	28	1	read	2026-02-19 01:39:50.298181+00
47	47	45	sent	2026-02-19 01:59:06.527995+00
41	41	1	read	2026-02-19 02:49:48.898053+00
38	38	1	read	2026-02-19 02:49:49.015828+00
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.notifications (id, user_id, type, title, body, created_at, read_at, priority) FROM stdin;
71	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Привет", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 00:09:29.989649+00	\N	normal
194	3	feed_post	New post in School Feed	{"type": "feed_post", "route": "/feeds", "title": "New post in School Feed", "content": {"blocks": [{"text": "New post in School Feed:", "type": "text", "style": "body"}, {"text": "Willkomen!", "type": "text", "style": "title"}], "actions": [{"icon": "dynamic_feed", "label": "Open Feeds", "route": "/feeds", "primary": true}]}, "metadata": {"feed_id": 1, "post_id": 1}}	2026-02-16 03:35:55.180821+00	\N	high
243	45	chat_message	New message from Timofei Kazantsev	{"type": "chat_message", "route": "/chat/6", "title": "New message from Timofei Kazantsev", "content": {"blocks": [{"text": "111", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 1, "thread_id": 6}}	2026-02-19 00:09:05.507801+00	\N	normal
244	45	chat_message	New message from Timofei Kazantsev	{"type": "chat_message", "route": "/chat/6", "title": "New message from Timofei Kazantsev", "content": {"blocks": [{"text": "Полав", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 1, "thread_id": 6}}	2026-02-19 01:59:06.536504+00	\N	normal
245	5	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Импровизируй", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 18, "teacher_name": "Timofei Kazantsev"}}	2026-02-19 02:25:53.907202+00	\N	normal
249	5	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "hollow Knight", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 20, "teacher_name": "Timofei Kazantsev"}}	2026-02-19 02:30:13.549668+00	\N	normal
253	33	feed_comment	New comment in Montags Mädchen Feed	{"type": "feed_comment", "route": "/feeds", "title": "New comment in Montags Mädchen Feed", "content": {"blocks": [{"text": "New comment on a post in Montags Mädchen Feed:", "type": "text", "style": "body"}, {"text": "Wird die Gruppe gehen?", "type": "text", "style": "title"}], "actions": [{"icon": "dynamic_feed", "label": "Open Feeds", "route": "/feeds", "primary": true}]}, "metadata": {"feed_id": 11, "post_id": 4}}	2026-02-19 11:35:40.6748+00	2026-02-19 11:35:58.536094+00	normal
242	45	chat_message	New message from Timofei Kazantsev	{"type": "chat_message", "route": "/chat/6", "title": "New message from Timofei Kazantsev", "content": {"blocks": [{"text": "Fhhjf", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 1, "thread_id": 6}}	2026-02-18 19:00:13.478371+00	\N	normal
246	12	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Импровизируй", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 18, "teacher_name": "Timofei Kazantsev"}}	2026-02-19 02:25:53.91391+00	\N	normal
177	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Dghd", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 03:15:02.69734+00	\N	normal
195	7	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Das neue Programm finden", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 7, "hometask_id": 3, "teacher_name": "Timofei Kazantsev"}}	2026-02-16 04:03:12.63814+00	2026-02-17 17:59:16.270622+00	normal
219	12	hometask_accomplished	Hometask Accomplished	{"type": "hometask_accomplished", "route": "/hometasks", "title": "Hometask Accomplished", "content": {"blocks": [{"text": "Timofei Kazantsev marked a hometask as accomplished:", "type": "text", "style": "body"}, {"text": "Посмотри новую программу", "type": "text", "style": "title"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 7, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 03:10:55.191127+00	\N	normal
196	8	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Häschen Klein", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 8, "hometask_id": 4, "teacher_name": "Timofei Kazantsev"}}	2026-02-16 04:05:51.974997+00	\N	normal
178	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Gdfg", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 03:15:13.392581+00	\N	normal
247	5	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "ходячий замок", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 19, "teacher_name": "Timofei Kazantsev"}}	2026-02-19 02:28:44.891037+00	\N	normal
218	1	hometask_accomplished	Hometask Accomplished	{"type": "hometask_accomplished", "route": "/hometasks", "title": "Hometask Accomplished", "content": {"blocks": [{"text": "Timofei Kazantsev marked a hometask as accomplished:", "type": "text", "style": "body"}, {"text": "Посмотри новую программу", "type": "text", "style": "title"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 7, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 03:10:54.064426+00	2026-02-18 04:05:34.001715+00	normal
140	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Ку", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 02:19:25.642328+00	\N	normal
248	12	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "ходячий замок", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 19, "teacher_name": "Timofei Kazantsev"}}	2026-02-19 02:28:44.897301+00	\N	normal
220	19	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Entscheiden, was du weiter spielen willst", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 19, "hometask_id": 8, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:44:30.82759+00	2026-02-19 11:37:42.101286+00	normal
198	9	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Denkt an dem Program", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 9, "hometask_id": 5, "teacher_name": "Timofei Kazantsev"}}	2026-02-16 04:06:33.786716+00	\N	normal
197	7	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Häschen Klein", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 8, "hometask_id": 4, "teacher_name": "Timofei Kazantsev"}}	2026-02-16 04:05:51.979047+00	2026-02-17 17:59:16.270622+00	normal
228	31	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Den Rumänischen Tanz vertig zu machen", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 29, "hometask_id": 11, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:53:40.715373+00	\N	normal
200	10	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Probiert mit Anna Martha Improvisieren, Ihr habt das nicht schlecht gemacht!", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 10, "hometask_id": 6, "teacher_name": "Timofei Kazantsev"}}	2026-02-16 04:08:02.876381+00	\N	normal
250	12	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "hollow Knight", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 20, "teacher_name": "Timofei Kazantsev"}}	2026-02-19 02:30:13.554125+00	\N	normal
221	21	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Entscheiden, was du weiter spielen willst", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 19, "hometask_id": 8, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:44:30.829935+00	\N	normal
84	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Ещё раз", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 00:21:21.445606+00	\N	normal
152	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Ку", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 02:30:20.122443+00	\N	normal
251	27	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "подумай, что ты сама хочешь играть", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 27, "hometask_id": 21, "teacher_name": "Timofei Kazantsev"}}	2026-02-19 02:59:04.167076+00	\N	normal
222	23	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Entscheiden, was du weiter spielen willst", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 19, "hometask_id": 8, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:44:30.832222+00	\N	normal
225	29	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Foolow me spielen", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 29, "hometask_id": 10, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:48:18.71182+00	\N	normal
153	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Ку", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 02:31:01.000124+00	\N	normal
204	1	chat_message	New message from Philine Meyreiß	{"type": "chat_message", "route": "/chat/2", "title": "New message from Philine Meyreiß", "content": {"blocks": [{"text": "Test Test :)", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 7, "thread_id": 2}}	2026-02-16 06:13:59.028773+00	\N	normal
252	28	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "подумай, что ты сама хочешь играть", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 27, "hometask_id": 21, "teacher_name": "Timofei Kazantsev"}}	2026-02-19 02:59:04.173291+00	\N	normal
206	1	chat_message	New message from Philine Meyreiß	{"type": "chat_message", "route": "/chat/2", "title": "New message from Philine Meyreiß", "content": {"blocks": [{"text": "Arietta und Elegie gefallen mir, leider konnte ich nicht direkt bei den Hausaufgaben antworten....", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 7, "thread_id": 2}}	2026-02-16 06:15:25.373966+00	\N	normal
223	27	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Учи болезнь куклы вместе с Ангелиной", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 27, "hometask_id": 9, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:46:06.540591+00	\N	normal
236	40	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Попробуй поиграть что-то своё", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 40, "hometask_id": 15, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 16:00:46.504623+00	\N	normal
224	28	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Учи болезнь куклы вместе с Ангелиной", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 27, "hometask_id": 9, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:46:06.543896+00	\N	normal
155	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Срота", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 02:37:55.562326+00	\N	normal
207	1	chat_message	New message from Selma Meyeriß	{"type": "chat_message", "route": "/chat/3", "title": "New message from Selma Meyeriß", "content": {"blocks": [{"text": "Auch hier klappt es 🚨🎉👌🙏🎹", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 8, "thread_id": 3}}	2026-02-16 06:49:35.952876+00	\N	normal
226	31	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Foolow me spielen", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 29, "hometask_id": 10, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:48:18.714603+00	\N	normal
156	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Цке", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 02:38:48.27512+00	\N	normal
208	7	chat_message	New message from Timofei Kazantsev	{"type": "chat_message", "route": "/chat/2", "title": "New message from Timofei Kazantsev", "content": {"blocks": [{"text": "Das wird ein nächster Schritt)", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 1, "thread_id": 2}}	2026-02-16 10:10:45.331227+00	\N	normal
227	29	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Den Rumänischen Tanz vertig zu machen", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 29, "hometask_id": 11, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:53:40.713287+00	\N	normal
157	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Цкн", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 02:57:37.932008+00	\N	normal
209	7	chat_message	New message from Timofei Kazantsev	{"type": "chat_message", "route": "/chat/2", "title": "New message from Timofei Kazantsev", "content": {"blocks": [{"text": "Ja, beide sind ziemlich einfach, es wird a walk in the Park 😉", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 1, "thread_id": 2}}	2026-02-16 10:11:19.194714+00	\N	normal
238	42	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Denkt weiter am Programm.", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 42, "hometask_id": 16, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 16:02:04.326846+00	\N	normal
192	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Почему?", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 03:17:09.07038+00	\N	normal
229	38	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Denkt, was du weiter spielen willst", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 38, "hometask_id": 12, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:56:11.405396+00	2026-02-18 21:44:57.260878+00	normal
210	7	hometask_accomplished	Hometask Accomplished	{"type": "hometask_accomplished", "route": "/hometasks", "title": "Hometask Accomplished", "content": {"blocks": [{"text": "Timofei Kazantsev marked a hometask as accomplished:", "type": "text", "style": "body"}, {"text": "Das neue Programm finden", "type": "text", "style": "title"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 7, "hometask_id": 3, "teacher_name": "Timofei Kazantsev"}}	2026-02-16 10:11:32.183412+00	2026-02-17 17:59:16.270622+00	normal
230	39	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Denkt, was du weiter spielen willst", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 38, "hometask_id": 12, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:56:11.737161+00	\N	normal
158	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Ccgh", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 02:59:09.954422+00	\N	normal
211	1	chat_message	New message from Philine Meyreiß	{"type": "chat_message", "route": "/chat/2", "title": "New message from Philine Meyreiß", "content": {"blocks": [{"text": "Oder hast du andere Empfehlungen?", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 7, "thread_id": 2}}	2026-02-16 10:49:57.13283+00	\N	normal
231	41	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Denkt, was du weiter spielen willst", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 38, "hometask_id": 12, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:56:12.037777+00	\N	normal
160	1	chat_message	New message from Sonya Kazantseva	{"type": "chat_message", "route": "/chat/1", "title": "New message from Sonya Kazantseva", "content": {"blocks": [{"text": "Fvbbj", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 4, "thread_id": 1}}	2026-02-16 03:00:48.067825+00	\N	normal
212	7	chat_message	New message from Timofei Kazantsev	{"type": "chat_message", "route": "/chat/2", "title": "New message from Timofei Kazantsev", "content": {"blocks": [{"text": "Nein nein, macht sie, viele leichte sind oft besser", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 1, "thread_id": 2}}	2026-02-16 10:51:15.802565+00	\N	normal
232	40	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Этюд", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 40, "hometask_id": 13, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:58:41.324931+00	\N	normal
213	1	chat_message	New message from Philine Meyreiß	{"type": "chat_message", "route": "/chat/2", "title": "New message from Philine Meyreiß", "content": {"blocks": [{"text": "Ok :)", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 7, "thread_id": 2}}	2026-02-16 11:07:43.070787+00	\N	normal
233	18	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Этюд", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 40, "hometask_id": 13, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:58:41.519245+00	\N	normal
235	18	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Follow Me", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 40, "hometask_id": 14, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:59:27.746802+00	\N	normal
237	18	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Попробуй поиграть что-то своё", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 40, "hometask_id": 15, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 16:00:46.609469+00	\N	normal
214	1	chat_message	New message from Philine Meyreiß	{"type": "chat_message", "route": "/chat/2", "title": "New message from Philine Meyreiß", "content": {"blocks": [{"text": "Vielleicht denke ich mir in beiden Tonarten noch zusätzlich eine Improvisation aus 😉", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 7, "thread_id": 2}}	2026-02-16 14:01:15.877678+00	\N	normal
234	40	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Follow Me", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 40, "hometask_id": 14, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 15:59:27.597705+00	\N	normal
215	7	chat_message	New message from Timofei Kazantsev	{"type": "chat_message", "route": "/chat/2", "title": "New message from Timofei Kazantsev", "content": {"blocks": [{"text": "👍", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 1, "thread_id": 2}}	2026-02-16 15:39:31.226684+00	\N	normal
239	44	hometask_assigned	New Hometask	{"type": "hometask_assigned", "route": "/hometasks", "title": "New Hometask", "content": {"blocks": [{"text": "Timofei Kazantsev assigned a new hometask:", "type": "text", "style": "body"}, {"text": "Valse", "type": "text", "style": "title"}, {"type": "spacer", "height": 8}, {"text": "Due: No due date", "type": "text", "style": "caption"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 44, "hometask_id": 17, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 17:28:13.694016+00	\N	normal
216	1	hometask_completed	Hometask Completed	{"type": "hometask_completed", "route": "/hometasks", "title": "Hometask Completed", "content": {"blocks": [{"text": "Sofia Kazantseva completed a hometask:", "type": "text", "style": "body"}, {"text": "Посмотри новую программу", "type": "text", "style": "title"}], "actions": [{"icon": "task", "label": "Review Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 7, "student_name": "Sofia Kazantseva"}}	2026-02-18 02:12:05.401407+00	2026-02-18 03:09:57.488278+00	normal
240	45	chat_message	New message from Timofei Kazantsev	{"type": "chat_message", "route": "/chat/6", "title": "New message from Timofei Kazantsev", "content": {"blocks": [{"text": "asdas", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 1, "thread_id": 6}}	2026-02-18 18:59:03.300201+00	\N	normal
217	5	hometask_accomplished	Hometask Accomplished	{"type": "hometask_accomplished", "route": "/hometasks", "title": "Hometask Accomplished", "content": {"blocks": [{"text": "Timofei Kazantsev marked a hometask as accomplished:", "type": "text", "style": "body"}, {"text": "Посмотри новую программу", "type": "text", "style": "title"}], "actions": [{"icon": "task", "label": "View Hometasks", "route": "/hometasks", "primary": true}]}, "metadata": {"student_id": 5, "hometask_id": 7, "teacher_name": "Timofei Kazantsev"}}	2026-02-18 03:10:54.060148+00	\N	normal
241	45	chat_message	New message from Timofei Kazantsev	{"type": "chat_message", "route": "/chat/6", "title": "New message from Timofei Kazantsev", "content": {"blocks": [{"text": "asdas", "type": "text", "style": "body"}]}, "metadata": {"sender_id": 1, "thread_id": 6}}	2026-02-18 18:59:36.495182+00	\N	normal
\.


--
-- Data for Name: parent_student_relations; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.parent_student_relations (parent_user_id, student_user_id, created_at) FROM stdin;
1	5	2026-02-16 03:21:40.759707+00
7	8	2026-02-16 03:24:15.401588+00
11	9	2026-02-16 03:48:12.131964+00
11	10	2026-02-16 03:48:12.131964+00
12	5	2026-02-16 06:56:14.216173+00
21	20	2026-02-18 14:50:24.23643+00
21	19	2026-02-18 14:50:24.23643+00
23	19	2026-02-18 14:51:45.803312+00
23	20	2026-02-18 14:51:45.803312+00
25	24	2026-02-18 14:54:37.842913+00
26	24	2026-02-18 14:55:09.216024+00
28	27	2026-02-18 15:03:25.018566+00
31	29	2026-02-18 15:06:17.987021+00
31	32	2026-02-18 15:08:10.308432+00
34	33	2026-02-18 15:18:51.505188+00
35	33	2026-02-18 15:19:41.936667+00
35	36	2026-02-18 15:22:56.172859+00
35	37	2026-02-18 15:22:56.210362+00
34	36	2026-02-18 15:23:11.364986+00
34	37	2026-02-18 15:23:11.412175+00
39	38	2026-02-18 15:27:39.134878+00
18	40	2026-02-18 15:31:20.543094+00
41	38	2026-02-18 15:37:43.205562+00
\.


--
-- Data for Name: parents; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.parents (user_id, status, archived_at, archived_by, created_at, updated_at) FROM stdin;
7	active	\N	\N	2026-02-16 03:24:15.401588+00	2026-02-16 03:24:15.401588+00
11	active	\N	\N	2026-02-16 03:48:12.131964+00	2026-02-16 03:48:12.131964+00
12	active	\N	\N	2026-02-16 06:56:14.216173+00	2026-02-16 06:56:14.216173+00
21	active	\N	\N	2026-02-18 14:50:24.23643+00	2026-02-18 14:50:24.23643+00
23	active	\N	\N	2026-02-18 14:51:45.803312+00	2026-02-18 14:51:45.803312+00
25	active	\N	\N	2026-02-18 14:54:37.842913+00	2026-02-18 14:54:37.842913+00
26	active	\N	\N	2026-02-18 14:55:09.216024+00	2026-02-18 14:55:09.216024+00
28	active	\N	\N	2026-02-18 15:03:25.018566+00	2026-02-18 15:03:25.018566+00
31	active	\N	\N	2026-02-18 15:06:17.987021+00	2026-02-18 15:06:17.987021+00
34	active	\N	\N	2026-02-18 15:18:51.505188+00	2026-02-18 15:18:51.505188+00
35	active	\N	\N	2026-02-18 15:19:41.936667+00	2026-02-18 15:19:41.936667+00
39	active	\N	\N	2026-02-18 15:27:39.134878+00	2026-02-18 15:27:39.134878+00
18	active	\N	\N	2026-02-18 15:31:20.543094+00	2026-02-18 15:31:20.543094+00
41	active	\N	\N	2026-02-18 15:37:43.205562+00	2026-02-18 15:37:43.205562+00
1	archived	2026-02-18 23:37:46.71164+00	1	2026-02-15 14:43:17.95236+00	2026-02-18 23:37:46.71164+00
\.


--
-- Data for Name: password_reset_requests; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.password_reset_requests (id, username, requested_at, resolved_at, resolved_by_admin_id) FROM stdin;
\.


--
-- Data for Name: password_reset_tokens; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.password_reset_tokens (id, user_id, token_hash, created_at, expires_at, used_at) FROM stdin;
1	1	$argon2id$v=19$m=19456,t=2,p=1$A4SrrM+egWBgzNGMQhN/wA$O6Yyk+nukdLzcuJVJRcfVLury6TtAayZDrfmc2o/0Qw	2026-02-15 14:02:36.640366+00	2026-02-15 15:02:36.639686+00	\N
3	1	$argon2id$v=19$m=19456,t=2,p=1$2942tVtqs+wgXrlFz9U4Cw$SJhZsWwhf8iv972oZRwReaDiS6SO7O11yDmsoAXzgM4	2026-02-15 14:07:15.359282+00	2026-02-15 15:07:15.358603+00	\N
\.


--
-- Data for Name: push_tokens; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.push_tokens (id, user_id, token, platform, created_at, last_seen_at, revoked_at) FROM stdin;
1	1	c8GPJ5MSdUjYS5FrauVNQ9:APA91bHuMv-BC7puAUMXXOXe-uXGWmzDoN8C7Gt4_wx9Ugu4c9WX14u1ZI6Uav94d9Y0dD_VZrK10fx_y8W1WeGtNphI2IVvoo2Cae5XhC-XG_3OgSsarbE	web	2026-02-15 21:05:54.577821+00	2026-02-15 21:05:54.577821+00	2026-02-15 22:36:09.172658+00
148	40	d2iS-WhYoauSGg4PABTHOq:APA91bGTwVAIhJAHt-_aVuyQRb0U1iQIzwKeWu-50A7FwcBloaC7t16WKdCX6OBsLX9vrnQgyW81G3Lgn83UHCa8IW4GB_XANbAA6wI6Eo9WhIeA8wPdYDA	web	2026-02-18 15:34:17.979813+00	2026-02-18 15:35:31.509109+00	\N
2	1	ffc-vKG9oVOL49o4dt9j-T:APA91bEbLc2u2pYxvcqxDLd7DU2QBLAEBJub-pQvNY3J7TNTys02-ngwA34e3kmkUWAzT-MvmYEqHi-hV1sxVbzBBcT6xIVm2cvGvYEhhfnZFRvkoVvokek	web	2026-02-15 23:04:53.971515+00	2026-02-15 23:04:53.971515+00	2026-02-15 23:05:16.342762+00
166	21	ejY1Dw0QSzcVGQuIUcoYwk:APA91bEDJnb8f4CVVZ2dOxz3f4YrnJc1fVYhTRTE2K6LT_moRIHdWjtNSR8P7FCPycQatmCa1y7VMbj2bWv4seg4545hORbjqsvQdVqEuIhFU--t6huNZQw	web	2026-02-18 16:26:20.649449+00	2026-02-18 16:26:20.649449+00	\N
50	1	c8GPJ5MSdUjYS5FrauVNQ9:APA91bH31mqsIQb-M8j6xC0GIoT7Vw_i7fQMJJMegEufoPNoRiV3laPT5wgBu_vnLN5Plt57W_5LgD7zJ5e2bjleKqHBMtuBO4X2V0iHHKbzxnTPRMI2Lhk	web	2026-02-16 02:06:48.917291+00	2026-02-16 02:06:48.917291+00	2026-02-16 02:26:08.020683+00
6	1	c6oh1lo5GXYkibCU_hAyPf:APA91bETrNFcFZZXIEsmrovA7uQHMIeZL2r1BPxvXdqaHYUgIc82xjqQyQb1YJSFd0-GE4jOJghpXC3MVvhy2fGqRO2DCTgmlqfSn8USLTlEXVvDQm5O_mg	web	2026-02-15 23:50:43.876381+00	2026-02-15 23:51:16.507909+00	2026-02-15 23:52:21.947897+00
79	1	dByWfLBzv09zTLmKtPMQwb:APA91bElNmN7KZ3yvpaoXESLt75aksp_1iuRtbm3wyF-HkP6u2HlH6UC_5bersmev2RMdbMXi21SiA2CX9pWPBJb-BLo_vI2AC4ewXdbW4MNsBTdQibxmAk	web	2026-02-16 04:52:07.901399+00	2026-02-16 04:57:35.383293+00	2026-02-16 06:13:59.16055+00
87	1	dByWfLBzv09zTLmKtPMQwb:APA91bEQeSUjcqmoKZ4SjMsvgaMj0DlmBpQjwcN-g94FpBFqowxr5jAdSebNnZbLGe9uktgDhAQ_J0GPuCLjNuJlI_o_py9LqVxvcOD-noNeOPT406PdNyE	web	2026-02-16 05:00:12.242781+00	2026-02-16 05:00:12.242781+00	2026-02-16 06:13:59.258919+00
88	1	dByWfLBzv09zTLmKtPMQwb:APA91bFSL19GkVZDfdodOeyhsMdBzQDqXTVUoKfL8p9HsnYTOXs5iCiFMfpImdNC5YZIBRT5Bi4B7nwbQ3Efog0AG_1qg0yR92inuO3JUr-mXIKBbd0PU4g	web	2026-02-16 05:00:12.776118+00	2026-02-16 05:00:12.776118+00	2026-02-16 06:13:59.322597+00
13	1	c8GPJ5MSdUjYS5FrauVNQ9:APA91bG9yb8FphuKcQPIKNZu5Ou3Vz_uQ06hsHCKkv3xdpGD-4MSoZaKQtzblc11w8Adm8NWiZnrS54992my4aEc9tXAevEAcGUcExSdZv3MIyzy-WNXLiw	web	2026-02-15 23:54:52.150369+00	2026-02-15 23:59:35.620659+00	2026-02-16 00:00:04.172458+00
9	1	c8GPJ5MSdUjYS5FrauVNQ9:APA91bGE0IEmXodEsKstZU3MSZfTCUCU69albrWm14nIw5l-UcGMsJM4MqLENyDyB_0xOffGt9CIlpkN4BKB3QB-ahz5TcTP9UYcICYbRK3ZzIdtO3GQ-EQ	web	2026-02-15 23:51:28.432544+00	2026-02-15 23:51:28.432544+00	2026-02-16 02:04:07.42977+00
10	1	eR9o7yAz9qnNrFhNb97kkL:APA91bFnW9UJDwtlUNomKmteKgkYOQnu1Qezm-j1LVODOohIgv6jt901grrNnysYsH9Tu0oIZ2jR8T7VvNSpcoMF0zbu_2Dsn58FwhDAH-QufUgJ3HssJe4	web	2026-02-15 23:51:45.045+00	2026-02-15 23:51:45.045+00	2026-02-16 02:04:07.497068+00
11	1	eR9o7yAz9qnNrFhNb97kkL:APA91bGX0a-Ozhl3Hchc2PHtLStwRukj4gd7ts1xLa1Q2QJjswuj_sMqbdW_dE5d5HQnbe3loUBuxJICMe-snuyQAePKhV3Fc7KV-byDkAX_qXZyZRu1sS8	web	2026-02-15 23:51:45.362727+00	2026-02-15 23:51:45.362727+00	2026-02-16 02:04:07.642795+00
89	1	dByWfLBzv09zTLmKtPMQwb:APA91bGuEp5tddUwIgp-6kSIiU6_saj9Bb8xbNompKaSSNZWBpKRIrxZo_ZesYjUzCSeDdhRJxT9yVRK0IjGRHK1O-amnYRo9QUmB6FcUTpi1uZbjrztAh0	web	2026-02-16 05:04:32.194947+00	2026-02-16 05:04:32.194947+00	2026-02-16 06:13:59.386778+00
57	1	c8GPJ5MSdUjYS5FrauVNQ9:APA91bHJi0gzAPJJCROXSs5uo8R-L5y224oBaLaL2sTm3f0-5KIxo2L-zu4DAQjZKoxLDrXw1R4ZVMXTuO8vpniywCuwR6CFue_dHqLEgS_mTmqUu54p6ts	web	2026-02-16 02:59:01.362384+00	2026-02-17 18:33:10.447891+00	\N
181	1	cnWzFpqrevYuQGgh9FFRBe:APA91bHv4qudS8_cGrD8-PrhRN-uazOE3W6UqHqWGkPuWLq4i2GPgTw8MTgNgRfUwhm2d0PCiA-8V_vPCQTfqxAYUjnYBzuODDNOqYJlwlSQIlvZJNMMztc	web	2026-02-18 18:58:55.968463+00	2026-02-18 19:05:18.795079+00	\N
180	1	f6E4x-JILM1comfiLSTExv:APA91bEr541Jlb9aRe-ggegOQpZ8TvBsZqtfawW9eJRUdlyobMuuiEjDLgHAL4wXw-gL-DDxf7U7a411FRT10Y1cY89j64eZ3grj2iDhJQKUeONUwfciSJ4	web	2026-02-18 18:49:08.900163+00	2026-02-18 18:49:08.900163+00	\N
12	1	c6oh1lo5GXYkibCU_hAyPf:APA91bH-RryrPM96W3onoAOj4EWrABXuVxh-u1iTIL5-RCSmpj164L9X6FkmhhXXxsMpSlZcmfjvqtgAis8BfbjVm4kz6GbAq9jGnAhqSwCUYU-Tm7jcf5Y	web	2026-02-15 23:52:41.503654+00	2026-02-15 23:52:41.503654+00	2026-02-16 02:04:07.778692+00
25	1	eA5sdLilWDtBGdVouTej6A:APA91bHJ2THqYOBiTuP6kVwz4NioSD9iwT5F4axv-VXa7TP8uCGpezUwxFiKyGfJLTb2f7yukQ1jsz-zhdiUcMRI9T3eivAfkQdZZyJ0Hp-Dl3AcKdKkbrk	web	2026-02-16 00:13:17.308202+00	2026-02-16 00:13:17.308202+00	2026-02-16 02:04:07.844331+00
21	1	c8GPJ5MSdUjYS5FrauVNQ9:APA91bE2J8l3cHOgzxqCySwx4l0FzOykCp37Ut3DrS6dntUPaudMLoVTBZkKVAjXjc9z0MM57yEZArFt155w3p9tiyBuLSEz5W0IN_KQiJNMN2akUHPHG7M	web	2026-02-16 00:09:19.038886+00	2026-02-16 00:30:26.796527+00	2026-02-16 02:04:08.096111+00
26	1	eA5sdLilWDtBGdVouTej6A:APA91bEG0Hbsud3-awLGAmZFUyHtFXtIusnJj8Cos1d0NcMoeLzSBMpd4Ja0EPbqUsbr2LjiTZEcQisVs4qBUqh5Yhc5XyzHx9217MFYU4ENXxzfNzTViCY	web	2026-02-16 00:13:18.089714+00	2026-02-16 00:31:34.134381+00	2026-02-16 02:04:08.172192+00
154	41	eWEKCennRBfwYgp2wEuH-G:APA91bE9efELOKZPU9FT8wYgsRS4DvnxEAbkL-OCIYzPRYFNM-D6UNrDzV0K69-eoiHFs4XVwc7W-t1c_E3wPO-cfOk-3bIsI2WMPlSKn3LZCTNos_MkBTw	web	2026-02-18 15:38:01.430213+00	2026-02-18 15:39:41.631783+00	\N
113	19	fzWy2BCLOHQxj17Gr1fbkG:APA91bHc-wxDnQX2TZGc5M8h_lJGgw10EupCRDEBHMHGF2hXT5qrBgbSVpOPwKcxrUyBPa7vP2QU8QZk6f4jzVT5DrgmgtZgX0GDl2Wp3dic6drLdRyvftA	web	2026-02-16 17:09:32.614131+00	2026-02-19 11:37:33.695768+00	\N
147	38	fPPnDEkYHxUKqkj9xb30qj:APA91bEj-imC7d8xhVXEUzz3x11fdg7r0Sdg64nZ_j565BV9_6zLJPrFsdHZtoM8RZyMNjk1HNiJuprHnpYv47HWrx-oILzuK8VaeBrSkz0a4jJ0XlKChjE	web	2026-02-18 15:27:34.178353+00	2026-02-18 15:27:34.178353+00	\N
51	1	clS81HtgD1tRHV9c6cAmNB:APA91bF2J61tsXjHQZPjZtS-WFRdWU1OtWuPIB-eF1BtQ56K2CS_Odyy0zcoHVq7IpW_9u8TgrIUhLw7r7DKDIo6tI6o92WZq2n4ktDOtU3sUwD5E6f9pnA	web	2026-02-16 02:21:22.981029+00	2026-02-16 02:21:22.981029+00	2026-02-16 02:28:13.674643+00
149	39	fF2EYeDQb52Qws2DTBfcq0:APA91bH9BLDfV1fyDQo22nUxyGudgJj40cVpwOq8rAvdTIrG_SpQfkTlr3Q6f7IELsCnyoAfOxA6XQGCzVdgF-YBe489Y46pytrK_k6qkCX8beawcgDc4Kw	web	2026-02-18 15:35:14.875791+00	2026-02-18 15:35:14.875791+00	\N
192	46	fCBm6PJR4G65Y3NNVVg2Uz:APA91bH8tfMNvriC-RYQ7sN97Tm43ZryxGyJtEITUw89X8vY130LO5dFfyG0qMzxLO4UcAvmVz8TtHcuReEoJwPqAXH5nR4BjDd9ePLoFN1eAt4pzXVLYm0	web	2026-02-18 20:20:00.179514+00	2026-02-18 20:40:50.426513+00	\N
91	7	dtnw-vSWB4ZdKmselrFVT4:APA91bH4MmLmkmUsUE481ygU7nYe3PIJjTwFM1MmPJB-fj6E6rEkIst1xSrfosQbK-8ZqaxGvvVvX4-ARbCQemZyG_RNyTdF-33_JUXbIlvCJpBqaFktxsw	web	2026-02-16 06:47:39.35463+00	2026-02-19 05:07:10.572097+00	\N
207	47	eeUWTQI15UGFcUVy83nRAw:APA91bFs3ZnjexhrFXP8sSCUUz0ZjKKufgsA-uaRh92J53K-ZpkmkgJ503do12MVWLq_SKRwbYWmOorMEKMWhYJARQWG3Jr-TEauEEklxaW0AArvFFU_oNs	web	2026-02-18 21:03:49.048157+00	2026-02-18 21:06:56.133869+00	\N
90	1	dByWfLBzv09zTLmKtPMQwb:APA91bFfj-dp48Peodi8cSZutoa_fM07hlNtg8MOSKEi1U9MtNAjMzmijwJYC7Hmo9FD8nWeftu2tADCHHo2qZ01V465sl5eFLxYIF7EfwoHluarDnpUdwk	web	2026-02-16 05:04:32.876573+00	2026-02-19 11:20:56.378008+00	\N
298	31	enyDR0M-4KXHlxBP-Efnk9:APA91bEQksT_OgYu5VThHZVuKd9J9fkMz0R-kvfMa3j_dBPO1_U83e6KsuXMaAbjRJq7u3P8u0xFq4CjXJ1gif82Yk4QNymiUaZffMXkckMLz4yH0lOfJ34	web	2026-02-19 10:32:02.056645+00	2026-02-19 10:43:01.162912+00	\N
56	1	c8GPJ5MSdUjYS5FrauVNQ9:APA91bErJmkm357PcxdSGWkPwDBSAeMTjaNe1GKHz61G0iDevTa5-UbbmpoOHtzn80VFuHkmWx5eSMCSRZhAPqftdG6INUX5DQJ_6q8To35-OxarUCB3VM8	web	2026-02-16 02:38:36.722899+00	2026-02-16 02:38:36.722899+00	2026-02-16 02:59:10.323534+00
58	11	eQUlv4xxsX-SD_c_uwqvut:APA91bENhCYpajSF1rEV6tx3lO2ro8KH3Y2j5i1pA_cykpBpNEab-lV3DbwaL_eQn0f1PZqt9tKKWFc5EqL1H2VAhG3wnoHCCemIAybuGsR-mh-i9gCJ_Yg	web	2026-02-16 03:13:58.324775+00	2026-02-16 04:11:25.95674+00	\N
3	1	ffc-vKG9oVOL49o4dt9j-T:APA91bHw-Oov8_D1CK0GBBSHidcBriKjuaGev1jxB_2XmE0alW5JQWl4fOpnYLxUndsUO2c_ML_j-WnrHxdL7DTnhMYm14frkxQBWGy9cbMYUHjok8-pmB8	web	2026-02-15 23:05:34.555959+00	2026-02-16 04:44:58.880634+00	\N
\.


--
-- Data for Name: registration_tokens; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.registration_tokens (id, token_hash, created_by_user_id, role, related_student_id, related_teacher_id, created_at, expires_at, used_at, used_by_user_id) FROM stdin;
2	33f30082aaa991f9f83d2643efbb91c5c7b8bbcb7a429c290749f28390c05969	1	student	\N	1	2026-02-16 03:25:02.261057+00	2026-02-18 03:25:02.260346+00	\N	\N
3	aaf5e3257074a76967dde39adc06820f16847eac89a81eb8df9cc4462218eb4f	1	student	\N	1	2026-02-16 03:25:45.592814+00	2026-02-18 03:25:45.592248+00	\N	\N
1	55a95d288ee95f0736cf948ce120dfe74d15d0b0f1867e0e32526968ab69d01c	1	parent	5	\N	2026-02-16 03:24:29.342261+00	2026-02-18 03:24:29.341581+00	2026-02-16 06:56:14.216173+00	12
5	ecd44466b657bfbaedf61b982597e60b5f628cd6d61af45e45f2c4779e97809c	1	student	\N	1	2026-02-18 15:09:11.099973+00	2026-02-20 15:09:11.099389+00	\N	\N
8	2d30ce0354ac40615b7fcc17519099bdcbb7da1a51ee5b2d5c0d14071efdc6b8	1	student	\N	1	2026-02-18 15:12:39.738878+00	2026-02-20 15:12:39.73822+00	\N	\N
6	f22fddedba468fcd10d3624f7a4c29b6d1fa5cdb3f0d13bd6ae01f3c694a97ca	1	student	\N	1	2026-02-18 15:09:33.224027+00	2026-02-20 15:09:33.223162+00	2026-02-18 15:23:42.692698+00	38
12	f03b806d59e1c652120ed679e6cd7beb95c09c4b6eb01da33696f21c8ebfdf32	1	student	\N	1	2026-02-18 15:25:21.441214+00	2026-02-20 15:25:21.440926+00	\N	\N
13	f6e86d3bab37c0d7be7781ba129df1609b4675fae8db82b56a7cd5ec4bd623fd	1	student	\N	1	2026-02-18 15:25:50.532652+00	2026-02-20 15:25:50.532426+00	\N	\N
14	1ef8e97e882364991ed09319e96e8da0978c20208451409ad4b3bc57233c76b7	1	student	\N	1	2026-02-18 15:26:29.906191+00	2026-02-20 15:26:29.905404+00	\N	\N
10	a152d27bb65afde56ee684229d2f289ea72352b33613dbcf628d3144f0647919	38	parent	38	\N	2026-02-18 15:24:08.816528+00	2026-02-20 15:24:08.815556+00	2026-02-18 15:27:39.134878+00	39
15	cd99eb6d2bdd1ec40ce75a7847cae41a31ac4c4026b056f253ea2bf7a48dc2c8	1	student	\N	1	2026-02-18 15:28:33.819472+00	2026-02-20 15:28:33.818555+00	\N	\N
16	cdcfb3518aafca3b25b0df032f65cc82b4bf8b0716d70d5606d4b953f4d1c37d	1	student	\N	1	2026-02-18 15:28:43.777133+00	2026-02-20 15:28:43.776232+00	\N	\N
17	d8a57168ecd8dfcab1fe775a9bde1ab851af2d7b3afdeaf71b30b485d3d57d32	1	student	\N	1	2026-02-18 15:29:19.871682+00	2026-02-20 15:29:19.871209+00	\N	\N
19	fdae7f46ec069fc2e51ec8dd3cbef7b62a275c44ee39c9323e33350d677cdbd5	1	student	\N	1	2026-02-18 15:37:05.216635+00	2026-02-20 15:37:05.216464+00	\N	\N
20	3fdcd3f08ff6e626bb3d408f48d79bdc92715b671b0c7edfb017e75e985b471e	1	student	\N	1	2026-02-18 15:37:19.600637+00	2026-02-20 15:37:19.600087+00	\N	\N
21	a94af515db8b3387f334a25465837c90d542a3f260c52f0af1f53cc1053a5b25	1	student	\N	1	2026-02-18 15:37:42.60349+00	2026-02-20 15:37:42.603035+00	\N	\N
18	d5a8af0f7acd7bc6118549a43c3e0149335b9939f9f97cc8b9bc64f0d6a5167f	38	parent	38	\N	2026-02-18 15:31:12.285529+00	2026-02-20 15:31:12.284924+00	2026-02-18 15:37:43.205562+00	41
11	79dad3f963a1f796129b60cdf54cf0537e58e036792a08a31929156afe7c2d69	1	student	\N	1	2026-02-18 15:24:31.752227+00	2026-02-20 15:24:31.751528+00	2026-02-18 15:48:25.024383+00	42
4	73c2fc4a01f1d552617f80b6b9b74efbcaecd7248a31bca7d439fc8e34537d5f	1	student	\N	1	2026-02-18 15:03:50.978979+00	2026-02-20 15:03:50.978202+00	2026-02-18 16:51:18.228065+00	44
7	545cf1fa9715503c2c537f5ea13be06a4adb8ab8f06809fdd07898379736383f	1	student	\N	1	2026-02-18 15:11:40.972063+00	2026-02-20 15:11:40.971258+00	2026-02-18 20:19:59.85962+00	46
9	8795865dc27555c8f35ff0a2f5702b409b0f3508413ecef5a59b27be601cd144	1	student	\N	1	2026-02-18 15:14:40.073599+00	2026-02-20 15:14:40.073302+00	2026-02-18 21:03:48.32991+00	47
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.roles (id, name, created_at) FROM stdin;
1	admin	2026-02-15 13:54:23.253121+00
2	teacher	2026-02-15 13:54:23.253121+00
3	parent	2026-02-15 13:54:23.253121+00
4	student	2026-02-15 13:54:23.253121+00
\.


--
-- Data for Name: student_groups; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.student_groups (id, teacher_user_id, name, status, archived_at, created_at, updated_at) FROM stdin;
1	1	Montags Mädchen	active	\N	2026-02-18 23:38:34.704954+00	2026-02-18 23:38:34.704954+00
2	1	Gebruder Kunz	active	\N	2026-02-19 00:10:44.138419+00	2026-02-19 00:10:44.138419+00
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.students (user_id, birthday, status, archived_at, archived_by, created_at, updated_at) FROM stdin;
5	2015-08-07	active	\N	\N	2026-02-16 03:19:00.211092+00	2026-02-16 03:19:00.211092+00
7	1987-04-03	active	\N	\N	2026-02-16 03:22:41.900598+00	2026-02-16 03:22:41.900598+00
8	2017-07-02	active	\N	\N	2026-02-16 03:23:26.237346+00	2026-02-16 03:23:26.237346+00
9	2012-05-25	active	\N	\N	2026-02-16 03:45:44.567425+00	2026-02-16 03:45:44.567425+00
10	2015-01-03	active	\N	\N	2026-02-16 03:47:03.076345+00	2026-02-16 03:47:03.076345+00
19	2014-07-04	active	\N	\N	2026-02-18 14:48:32.548497+00	2026-02-18 14:48:32.548497+00
20	2014-07-04	active	\N	\N	2026-02-18 14:49:23.691767+00	2026-02-18 14:49:23.691767+00
24	2015-02-22	active	\N	\N	2026-02-18 14:54:02.197101+00	2026-02-18 14:54:02.197101+00
27	2016-08-15	active	\N	\N	2026-02-18 15:00:57.746072+00	2026-02-18 15:00:57.746072+00
28	1999-10-17	active	\N	\N	2026-02-18 15:02:08.266259+00	2026-02-18 15:02:08.266259+00
29	2011-08-05	active	\N	\N	2026-02-18 15:05:02.61457+00	2026-02-18 15:05:02.61457+00
32	2006-11-06	active	\N	\N	2026-02-18 15:07:49.821115+00	2026-02-18 15:07:49.821115+00
33	2018-01-05	active	\N	\N	2026-02-18 15:17:43.968163+00	2026-02-18 15:17:43.968163+00
36	2011-04-21	active	\N	\N	2026-02-18 15:20:29.199656+00	2026-02-18 15:20:29.199656+00
37	2008-08-21	active	\N	\N	2026-02-18 15:22:41.348398+00	2026-02-18 15:22:41.348398+00
38	2010-09-18	active	\N	\N	2026-02-18 15:23:42.692698+00	2026-02-18 15:23:42.692698+00
40	2019-01-01	active	\N	\N	2026-02-18 15:31:07.54165+00	2026-02-18 15:31:07.54165+00
42	2010-08-12	active	\N	\N	2026-02-18 15:48:25.024383+00	2026-02-18 15:48:25.024383+00
44	1988-08-22	active	\N	\N	2026-02-18 16:51:18.228065+00	2026-02-18 16:51:18.228065+00
45	2000-01-01	active	\N	\N	2026-02-18 17:09:19.53914+00	2026-02-18 17:09:19.53914+00
46	1964-03-04	active	\N	\N	2026-02-18 20:19:59.85962+00	2026-02-18 20:19:59.85962+00
47	1980-06-08	active	\N	\N	2026-02-18 21:03:48.32991+00	2026-02-18 21:03:48.32991+00
\.


--
-- Data for Name: teacher_student_relations; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.teacher_student_relations (teacher_user_id, student_user_id, created_at) FROM stdin;
1	7	2026-02-16 03:25:00.028462+00
1	8	2026-02-16 03:25:00.071865+00
1	5	2026-02-16 03:25:00.118953+00
1	9	2026-02-16 04:02:08.388223+00
1	10	2026-02-16 04:02:08.439326+00
18	20	2026-02-18 14:52:23.102183+00
1	19	2026-02-18 14:59:39.861884+00
1	20	2026-02-18 14:59:39.905234+00
1	24	2026-02-18 14:59:39.940935+00
1	28	2026-02-18 15:03:11.138518+00
1	27	2026-02-18 15:03:11.179921+00
1	29	2026-02-18 15:08:45.430809+00
1	32	2026-02-18 15:08:45.471499+00
1	33	2026-02-18 15:23:32.997458+00
1	36	2026-02-18 15:23:33.038893+00
1	37	2026-02-18 15:23:33.079979+00
1	38	2026-02-18 15:23:42.692698+00
1	40	2026-02-18 15:31:40.672774+00
1	42	2026-02-18 15:48:25.024383+00
18	24	2026-02-18 16:33:20.678754+00
1	44	2026-02-18 16:51:18.228065+00
1	46	2026-02-18 20:19:59.85962+00
1	47	2026-02-18 21:03:48.32991+00
\.


--
-- Data for Name: teachers; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.teachers (user_id, status, archived_at, archived_by, created_at, updated_at) FROM stdin;
3	active	\N	\N	2026-02-15 13:55:28.255152+00	2026-02-15 13:55:28.255152+00
13	active	\N	\N	2026-02-17 20:38:04.468685+00	2026-02-17 20:38:04.468685+00
14	active	\N	\N	2026-02-18 14:41:47.702572+00	2026-02-18 14:41:47.702572+00
15	active	\N	\N	2026-02-18 14:42:48.695694+00	2026-02-18 14:42:48.695694+00
17	active	\N	\N	2026-02-18 14:44:28.014162+00	2026-02-18 14:44:28.014162+00
18	active	\N	\N	2026-02-18 14:46:38.971028+00	2026-02-18 14:46:38.971028+00
43	active	\N	\N	2026-02-18 16:10:42.311972+00	2026-02-18 16:10:42.311972+00
1	active	\N	\N	2026-02-15 14:43:34.657539+00	2026-02-18 23:25:23.24168+00
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.user_roles (user_id, role_id, assigned_at) FROM stdin;
3	2	2026-02-15 13:55:28.255152+00
1	1	2026-02-15 13:59:37.007163+00
1	3	2026-02-15 14:43:17.95236+00
1	2	2026-02-15 14:43:34.657539+00
5	4	2026-02-16 03:19:00.211092+00
7	4	2026-02-16 03:22:41.900598+00
8	4	2026-02-16 03:23:26.237346+00
7	3	2026-02-16 03:24:15.401588+00
9	4	2026-02-16 03:45:44.567425+00
10	4	2026-02-16 03:47:03.076345+00
11	3	2026-02-16 03:48:12.131964+00
12	3	2026-02-16 06:56:14.216173+00
13	2	2026-02-17 20:38:04.468685+00
14	2	2026-02-18 14:41:47.702572+00
15	2	2026-02-18 14:42:48.695694+00
17	2	2026-02-18 14:44:28.014162+00
18	2	2026-02-18 14:46:38.971028+00
19	4	2026-02-18 14:48:32.548497+00
20	4	2026-02-18 14:49:23.691767+00
21	3	2026-02-18 14:50:24.23643+00
23	3	2026-02-18 14:51:45.803312+00
24	4	2026-02-18 14:54:02.197101+00
25	3	2026-02-18 14:54:37.842913+00
26	3	2026-02-18 14:55:09.216024+00
27	4	2026-02-18 15:00:57.746072+00
28	4	2026-02-18 15:02:08.266259+00
28	3	2026-02-18 15:03:25.018566+00
29	4	2026-02-18 15:05:02.61457+00
31	3	2026-02-18 15:06:17.987021+00
32	4	2026-02-18 15:07:49.821115+00
33	4	2026-02-18 15:17:43.968163+00
34	3	2026-02-18 15:18:51.505188+00
35	3	2026-02-18 15:19:41.936667+00
36	4	2026-02-18 15:20:29.199656+00
37	4	2026-02-18 15:22:41.348398+00
38	4	2026-02-18 15:23:42.692698+00
39	3	2026-02-18 15:27:39.134878+00
40	4	2026-02-18 15:31:07.54165+00
18	3	2026-02-18 15:31:20.543094+00
41	3	2026-02-18 15:37:43.205562+00
42	4	2026-02-18 15:48:25.024383+00
43	2	2026-02-18 16:10:42.311972+00
44	4	2026-02-18 16:51:18.228065+00
45	4	2026-02-18 17:09:19.53914+00
46	4	2026-02-18 20:19:59.85962+00
47	4	2026-02-18 21:03:48.32991+00
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: klavier
--

COPY public.users (id, username, full_name, password_hash, email, phone, profile_image, created_at) FROM stdin;
3	patrick	Patrick Schulze	$argon2id$v=19$m=19456,t=2,p=1$6LGGcY0xIKFxI9CdcWRuMw$jBCL2eZ97XxuSBNEGVvSI9qSiMB1acPa8DmXzQAm9Us	\N	\N	\N	2026-02-15 13:55:28.255152+00
15	lSchnejdar	Lisa Schnejdar	$argon2id$v=19$m=19456,t=2,p=1$cL2QLKR0FldP4lmVteAHeQ$p5ZE5VcvtdICgV8+r8Cp4nUx/XzWIRlhmeCcRMeny+k	\N	\N	\N	2026-02-18 14:42:48.695694+00
17	treis	Tatjana Reis	$argon2id$v=19$m=19456,t=2,p=1$1b+ZGsfUEbYbIE/jg+9vTA$AEljsSWqUG6C5yDhjgpSbP7m6tjTcbwDa5uZ/VbNwLs	\N	\N	\N	2026-02-18 14:44:28.014162+00
18	lnutzko	Larisa Nutzko	$argon2id$v=19$m=19456,t=2,p=1$JXa4Ok6gGab8e/kkHNSNWA$kFDNpYl22SKBCR6ii5MBUPK7X2JUzskmoRoNtXGz9Qk	\N	\N	\N	2026-02-18 14:46:38.971028+00
19	eremus	Emmi Remus	$argon2id$v=19$m=19456,t=2,p=1$bte+Rh64bn4G7KUCkt+bqw$ttU9FCPNyQb8X1q8ueJG2mWJRj4SXoQjOYWC/oOWl3s	\N	\N	\N	2026-02-18 14:48:32.548497+00
20	lremus	Lilly Remus	$argon2id$v=19$m=19456,t=2,p=1$iIB9wjOdM6oJ+VazTYr+DA$FLHKanGBHfs8ax5cxZnQoKpTtP6C5NsmhlqhN0VjJI0	\N	\N	\N	2026-02-18 14:49:23.691767+00
21	nremus	Nico Remus	$argon2id$v=19$m=19456,t=2,p=1$aVz0Sz/EMyNPH32QSwHt8A$0n1CBimwFfFdXj6vYnNU8eNHYjlJDn1tfPw7xyZJL2Y	\N	\N	\N	2026-02-18 14:50:24.23643+00
23	sremus	Stephanie Remus	$argon2id$v=19$m=19456,t=2,p=1$T/4oUcUDOavQmmzTuJWVZg$SuAm1eXGBvIAfNVcXL+NAf0VdP+PzQTwgBabNe6aYQM	\N	\N	\N	2026-02-18 14:51:45.803312+00
24	lschubotz	Lukas Schubotz	$argon2id$v=19$m=19456,t=2,p=1$P6maAJWJjWtNCtM50S6viQ$pPCuuZ43j+f7v+dDLGXMP23DSBCHg7QHV/MQ31c2Tqw	\N	\N	\N	2026-02-18 14:54:02.197101+00
25	iltsai	Ilona Tsai	$argon2id$v=19$m=19456,t=2,p=1$gPv4HIB9JIwzoQRQkQp+uA$1g6cFheQnnh4lnMO2HVJnbK6q4aRHWWF2WMYjilbGWs	\N	\N	\N	2026-02-18 14:54:37.842913+00
26	tschubotz	Thobias Schubotz	$argon2id$v=19$m=19456,t=2,p=1$Goa1qbPERg4/RrAF9KFB7A$Wxqm2oAuYGsHFs8Ir0lbHHIqKlN0VsdTvVsE2FR/iDI	\N	\N	\N	2026-02-18 14:55:09.216024+00
27	adwenz	Adelina Wenz	$argon2id$v=19$m=19456,t=2,p=1$+CZwJL+cPs3xvzEf1T3ZeQ$Hn8VMExTnIgQ5bvNjREl3jhqvkmJ98pbtZ4ZbYPJXTQ	\N	\N	\N	2026-02-18 15:00:57.746072+00
28	anmarchuk	Angelina Marchuk	$argon2id$v=19$m=19456,t=2,p=1$XCRDbFaeDwv41q7mL8if4Q$YYk4VorwFMKcaDhWeDOTHpQS73M2UxHNsuY6c+o6/U8	\N	\N	\N	2026-02-18 15:02:08.266259+00
29	fkunz	Fabian Kunz	$argon2id$v=19$m=19456,t=2,p=1$rk3Oatu/ZEZEQ1Ozng/BRg$PQHfb7R+/JzjpXlCRN3vNqaOQx/dUPfQ7+E85yGMm/M	\N	\N	\N	2026-02-18 15:05:02.61457+00
1	levitanus	Timofei Kazantsev	$argon2id$v=19$m=19456,t=2,p=1$USoFResJ96d7VGj4+YS1xg$69S2BHV2ZbXtHel9pRQvZKXDHkI6kGvhf/xHKldFWa4	art@tkazantsev.org	\N	levitanus_b68cad97-080c-457d-973d-70206ab52806.jpg	2026-02-15 13:54:23.253121+00
31	kkunz	Katheleen Kunz	$argon2id$v=19$m=19456,t=2,p=1$i82Epy3Db9umJodVbluRvA$iB6Mpk68kzZFGhnBjpVNi8g52vo96zVmKKum4+I0tvY	\N	\N	\N	2026-02-18 15:06:17.987021+00
32	jkunz	Jonathan Kunz	$argon2id$v=19$m=19456,t=2,p=1$a7hjnWZLuRCTdSCULzB+Xw$/8/jaen2HDHCbqrk4phr+v9VCa/8ID5t5YEZOzpqc10	\N	\N	\N	2026-02-18 15:07:49.821115+00
33	manguyen	Mihn Ahn Nguyen	$argon2id$v=19$m=19456,t=2,p=1$PCUfDW269HFWr6DVEmzvjQ$8Ols2z7boJY4+11+J8uMBfUA9Z2QCmw5ZXYKzL9JMWU	\N	\N	\N	2026-02-18 15:17:43.968163+00
34	tpnguyen	Thi Phuong Nguyen	$argon2id$v=19$m=19456,t=2,p=1$l4hqelKJuZKfVHu4cBNZbQ$LYtKCUACZOzR0vJAcJaak527/xQ4y+mqKyjS+uYx8VQ	\N	\N	\N	2026-02-18 15:18:51.505188+00
35	lnguyen	Lam Nguyen	$argon2id$v=19$m=19456,t=2,p=1$+g5j/SIht0IoIq1uoQgkkQ$MdDy6pVsCbvbTAc98enJ2xN71bYLtmacdh91sNnfq5w	\N	\N	\N	2026-02-18 15:19:41.936667+00
36	tmnguyen	Thai Mihn Nguyen	$argon2id$v=19$m=19456,t=2,p=1$fAVmgCPABzRqzJJF1rdoTw$Xgf9N+GNBuGJ+uABvSqJEW1Aouu2fXgnWtVADpg6Epk	\N	\N	\N	2026-02-18 15:20:29.199656+00
5	SofiaCotofei	Sofia Kazantseva	$argon2id$v=19$m=19456,t=2,p=1$hT+RQUMlBQlXvvygASlOHg$yDLsSdrEMvtR6vCU3fzCNsNVIhpagc7aW8ZSbRnKsms	\N	\N	\N	2026-02-16 03:19:00.211092+00
37	tlnguyen	Thai Lai Nguyen	$argon2id$v=19$m=19456,t=2,p=1$lhvAu/o+1i1/j2tNZbGiDg$5HoMl3fTxHRA8gb1OGQZZpXzYOI5e1qnS+BRSXrlkkk	\N	\N	\N	2026-02-18 15:22:41.348398+00
38	Emily	Emily Höber	$argon2id$v=19$m=19456,t=2,p=1$2gIr/Wp0b1PRs2pFbIq4YA$yeSyV060SxqTumPMrLtzl3NqznohjRQ0KmEZChLQm+4	\N	+49 152 05793635	\N	2026-02-18 15:23:42.692698+00
39	Ina	Ina Höber	$argon2id$v=19$m=19456,t=2,p=1$/Dihijf2YoHQu+zSiup1ow$n/o1qWwn5EJmZMLod8RYTqxfXzijJoHcAy7Y9h4f2wY	i.a.hoeber@gmail.com	+491725879564	\N	2026-02-18 15:27:39.134878+00
7	philinne	Philine Meyreiß	$argon2id$v=19$m=19456,t=2,p=1$6QvtKirTUatRJMYFG+9++g$VN8UKhzxTNBdHMko/P9udLiMFNAk3bCZAYBzn7wD6EQ	\N	\N	\N	2026-02-16 03:22:41.900598+00
8	selma	Selma Meyeriß	$argon2id$v=19$m=19456,t=2,p=1$zCQeJ4BXWidkyMCGQWIqkA$JQfjeMB5+O/SVu2Fd9zwsZwuR/8Ug+HL0wchugoy0tU	\N	\N	\N	2026-02-16 03:23:26.237346+00
9	amwolf	Anna Martha Wolf	$argon2id$v=19$m=19456,t=2,p=1$cRZu9kO6PAJOMbtTf8p3iA$kTo9/eEe2e5U+OIFnvEsTRJBHxNxw9hb4iVm8xLQxYw	\N	\N	\N	2026-02-16 03:45:44.567425+00
10	ewolf	Elisabeth Wolf	$argon2id$v=19$m=19456,t=2,p=1$1a2g6F6Zd6Yx74pELKKMcg$/8VriDPUT0qZ0LOzXbgUVijxkeo7FygR0v397mfZ7R4	\N	\N	\N	2026-02-16 03:47:03.076345+00
11	uwolf	Ulrike Wolf	$argon2id$v=19$m=19456,t=2,p=1$PnPusKd9bCl5RlCypPXNIA$xGwE4nwp4tYyV0RScMADhGYOh3RUw9Cv/KWhem5Hj4o	\N	\N	\N	2026-02-16 03:48:12.131964+00
12	Alena 	Kazantseva 	$argon2id$v=19$m=19456,t=2,p=1$mB6HMhTJP3brzYrwzY//9g$8UtxVWnNYI9U3NtKWIilJdixznQt/8sNkJN4trQNlYI	madam.kaza2015@gmail.com	\N	Alena _6a113e67-5637-49c2-83c5-b2b841d853c5.jpg	2026-02-16 06:56:14.216173+00
13	dbek	Dimitri Bekdurdyew	$argon2id$v=19$m=19456,t=2,p=1$ZNoSke2lltqjusbcnW/etQ$dcg+JZjoV5akR9R2KTp8l3FpGEZ1ZawSPkPo/+eP0cA	\N	\N	\N	2026-02-17 20:38:04.468685+00
14	etaruntsov	Jevgenij Taruntsov	$argon2id$v=19$m=19456,t=2,p=1$NhA5uFtDv6fO9ntpK2NuFg$4MmPw23WkZ6pldt4mdgQNBxqpJIyixlC07AgzD7542w	\N	\N	\N	2026-02-18 14:41:47.702572+00
40	anutzko	Arsen Nutzko	$argon2id$v=19$m=19456,t=2,p=1$22VTkQ7WKFzfTbtQXHMHvg$h8bOQqkoiPSQWgaKgHygetcs0R48wX5iwyt2HSAI7bA	\N	\N	\N	2026-02-18 15:31:07.54165+00
41	Andreas Höber	Andreas Höber	$argon2id$v=19$m=19456,t=2,p=1$LB13ctFNYSGcS35GfWjv0Q$LX1GNCsxFtwwUowCLB6E8Cnu+hFeYiECMTuj11fSp8w	\N	\N	\N	2026-02-18 15:37:43.205562+00
42	Oscar Maasch	Oscar Ferdinand Maasch	$argon2id$v=19$m=19456,t=2,p=1$D2b4PpMbIFJ2zGKiEDthvg$dUaxmpJIgx2cmsv/X7b/lEOMqP+vgbfcLVHhHtMKTH0	oscar.maasch@gmail.com	\N	\N	2026-02-18 15:48:25.024383+00
43	cvegas	Constanze Bischoff	$argon2id$v=19$m=19456,t=2,p=1$qjFqb8eYmkhXzJ5KYNLwjg$G9Z7bK1cbyl0rd5nHYJ3ZeJhxgooe+dxZv4XEbn+yMc	\N	\N	\N	2026-02-18 16:10:42.311972+00
44	cliu	Chi Liu	$argon2id$v=19$m=19456,t=2,p=1$dWMLuQST2/IvykPpQ2WeKA$Ww1YHe8GsA/chN+RYRDkvovTB/RFpl1uW+z/MpKrX1Q	liuchink822@gmail.com	01735683734	\N	2026-02-18 16:51:18.228065+00
45	test-student	Test student	$argon2id$v=19$m=19456,t=2,p=1$AbGLpS0ZVq6tCd1Z0F7XiQ$yN4nj7OoYgYIatAfw9FQ456MkK9XGTcWDxnPfb9GGIY	\N	\N	\N	2026-02-18 17:09:19.53914+00
46	kalut	Katrin Luther	$argon2id$v=19$m=19456,t=2,p=1$sFxzvvehdp0oQdVHGmRxpw$Y7hwwPkgCi4hfNBNBi1CwB6xKdbfHFnSFtqs0Rp9taU	ktrnlthr@gmail.com	015781784557	\N	2026-02-18 20:19:59.85962+00
47	Marika	Marika Tóth 	$argon2id$v=19$m=19456,t=2,p=1$WAOWmc+g4OqF13PxbyR7RQ$7q0FBAoUlaInx5e7jGsPQoagFhRDqEgcku7T6LsD4Ss	\N	\N	\N	2026-02-18 21:03:48.32991+00
\.


--
-- Name: jobid_seq; Type: SEQUENCE SET; Schema: cron; Owner: klavier
--

SELECT pg_catalog.setval('cron.jobid_seq', 1, true);


--
-- Name: runid_seq; Type: SEQUENCE SET; Schema: cron; Owner: klavier
--

SELECT pg_catalog.setval('cron.runid_seq', 2, true);


--
-- Name: chat_message_attachments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.chat_message_attachments_id_seq', 1, false);


--
-- Name: chat_messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.chat_messages_id_seq', 47, true);


--
-- Name: chat_threads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.chat_threads_id_seq', 7, true);


--
-- Name: feed_comments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.feed_comments_id_seq', 2, true);


--
-- Name: feed_posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.feed_posts_id_seq', 4, true);


--
-- Name: feeds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.feeds_id_seq', 12, true);


--
-- Name: group_hometask_assignments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.group_hometask_assignments_id_seq', 1, false);


--
-- Name: hometask_checklists_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.hometask_checklists_id_seq', 10, true);


--
-- Name: hometask_submissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.hometask_submissions_id_seq', 1, false);


--
-- Name: hometasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.hometasks_id_seq', 21, true);


--
-- Name: media_files_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.media_files_id_seq', 1, false);


--
-- Name: message_receipts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.message_receipts_id_seq', 47, true);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.notifications_id_seq', 253, true);


--
-- Name: password_reset_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.password_reset_requests_id_seq', 1, false);


--
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.password_reset_tokens_id_seq', 4, true);


--
-- Name: push_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.push_tokens_id_seq', 335, true);


--
-- Name: registration_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.registration_tokens_id_seq', 21, true);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.roles_id_seq', 4, true);


--
-- Name: student_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.student_groups_id_seq', 2, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: klavier
--

SELECT pg_catalog.setval('public.users_id_seq', 47, true);


--
-- Name: _sqlx_migrations _sqlx_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public._sqlx_migrations
    ADD CONSTRAINT _sqlx_migrations_pkey PRIMARY KEY (version);


--
-- Name: chat_message_attachments chat_message_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_message_attachments
    ADD CONSTRAINT chat_message_attachments_pkey PRIMARY KEY (id);


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: chat_presence chat_presence_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_presence
    ADD CONSTRAINT chat_presence_pkey PRIMARY KEY (user_id);


--
-- Name: chat_threads chat_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_threads
    ADD CONSTRAINT chat_threads_pkey PRIMARY KEY (id);


--
-- Name: feed_comment_media feed_comment_media_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_comment_media
    ADD CONSTRAINT feed_comment_media_pkey PRIMARY KEY (comment_id, media_id);


--
-- Name: feed_comments feed_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_comments
    ADD CONSTRAINT feed_comments_pkey PRIMARY KEY (id);


--
-- Name: feed_post_media feed_post_media_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_post_media
    ADD CONSTRAINT feed_post_media_pkey PRIMARY KEY (post_id, media_id);


--
-- Name: feed_post_reads feed_post_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_post_reads
    ADD CONSTRAINT feed_post_reads_pkey PRIMARY KEY (post_id, user_id);


--
-- Name: feed_post_subscriptions feed_post_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_post_subscriptions
    ADD CONSTRAINT feed_post_subscriptions_pkey PRIMARY KEY (post_id, user_id);


--
-- Name: feed_posts feed_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_posts
    ADD CONSTRAINT feed_posts_pkey PRIMARY KEY (id);


--
-- Name: feed_settings feed_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_settings
    ADD CONSTRAINT feed_settings_pkey PRIMARY KEY (feed_id);


--
-- Name: feed_user_settings feed_user_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_user_settings
    ADD CONSTRAINT feed_user_settings_pkey PRIMARY KEY (feed_id, user_id);


--
-- Name: feeds feeds_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feeds
    ADD CONSTRAINT feeds_pkey PRIMARY KEY (id);


--
-- Name: group_hometask_assignments group_hometask_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.group_hometask_assignments
    ADD CONSTRAINT group_hometask_assignments_pkey PRIMARY KEY (id);


--
-- Name: group_student_relations group_student_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.group_student_relations
    ADD CONSTRAINT group_student_relations_pkey PRIMARY KEY (group_id, student_user_id);


--
-- Name: hometask_checklists hometask_checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometask_checklists
    ADD CONSTRAINT hometask_checklists_pkey PRIMARY KEY (id);


--
-- Name: hometask_submissions hometask_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometask_submissions
    ADD CONSTRAINT hometask_submissions_pkey PRIMARY KEY (id);


--
-- Name: hometasks hometasks_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometasks
    ADD CONSTRAINT hometasks_pkey PRIMARY KEY (id);


--
-- Name: media_files media_files_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.media_files
    ADD CONSTRAINT media_files_pkey PRIMARY KEY (id);


--
-- Name: media_files media_files_storage_key_key; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.media_files
    ADD CONSTRAINT media_files_storage_key_key UNIQUE (storage_key);


--
-- Name: message_receipts message_receipts_message_id_recipient_id_key; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.message_receipts
    ADD CONSTRAINT message_receipts_message_id_recipient_id_key UNIQUE (message_id, recipient_id);


--
-- Name: message_receipts message_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.message_receipts
    ADD CONSTRAINT message_receipts_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: parent_student_relations parent_student_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.parent_student_relations
    ADD CONSTRAINT parent_student_relations_pkey PRIMARY KEY (parent_user_id, student_user_id);


--
-- Name: parents parents_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.parents
    ADD CONSTRAINT parents_pkey PRIMARY KEY (user_id);


--
-- Name: password_reset_requests password_reset_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.password_reset_requests
    ADD CONSTRAINT password_reset_requests_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);


--
-- Name: push_tokens push_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.push_tokens
    ADD CONSTRAINT push_tokens_pkey PRIMARY KEY (id);


--
-- Name: push_tokens push_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.push_tokens
    ADD CONSTRAINT push_tokens_token_key UNIQUE (token);


--
-- Name: registration_tokens registration_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.registration_tokens
    ADD CONSTRAINT registration_tokens_pkey PRIMARY KEY (id);


--
-- Name: registration_tokens registration_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.registration_tokens
    ADD CONSTRAINT registration_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: student_groups student_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.student_groups
    ADD CONSTRAINT student_groups_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (user_id);


--
-- Name: teacher_student_relations teacher_student_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.teacher_student_relations
    ADD CONSTRAINT teacher_student_relations_pkey PRIMARY KEY (teacher_user_id, student_user_id);


--
-- Name: teachers teachers_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_pkey PRIMARY KEY (user_id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_chat_message_attachments_message; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_chat_message_attachments_message ON public.chat_message_attachments USING btree (message_id);


--
-- Name: idx_chat_messages_created_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_chat_messages_created_at ON public.chat_messages USING btree (created_at DESC);


--
-- Name: idx_chat_messages_sender; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_chat_messages_sender ON public.chat_messages USING btree (sender_id);


--
-- Name: idx_chat_messages_thread; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_chat_messages_thread ON public.chat_messages USING btree (thread_id);


--
-- Name: idx_chat_presence_is_online; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_chat_presence_is_online ON public.chat_presence USING btree (is_online);


--
-- Name: idx_chat_threads_is_admin; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_chat_threads_is_admin ON public.chat_threads USING btree (is_admin_chat);


--
-- Name: idx_chat_threads_participant_a; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_chat_threads_participant_a ON public.chat_threads USING btree (participant_a_id);


--
-- Name: idx_chat_threads_participant_b; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_chat_threads_participant_b ON public.chat_threads USING btree (participant_b_id);


--
-- Name: idx_chat_threads_updated_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_chat_threads_updated_at ON public.chat_threads USING btree (updated_at DESC);


--
-- Name: idx_feed_comment_media_comment; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_comment_media_comment ON public.feed_comment_media USING btree (comment_id);


--
-- Name: idx_feed_comments_parent; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_comments_parent ON public.feed_comments USING btree (parent_comment_id);


--
-- Name: idx_feed_comments_post; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_comments_post ON public.feed_comments USING btree (post_id);


--
-- Name: idx_feed_post_media_post; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_post_media_post ON public.feed_post_media USING btree (post_id);


--
-- Name: idx_feed_post_reads_post_id; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_post_reads_post_id ON public.feed_post_reads USING btree (post_id);


--
-- Name: idx_feed_post_reads_user_id; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_post_reads_user_id ON public.feed_post_reads USING btree (user_id);


--
-- Name: idx_feed_post_subscriptions_user; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_post_subscriptions_user ON public.feed_post_subscriptions USING btree (user_id);


--
-- Name: idx_feed_posts_created_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_posts_created_at ON public.feed_posts USING btree (created_at DESC);


--
-- Name: idx_feed_posts_feed; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_posts_feed ON public.feed_posts USING btree (feed_id);


--
-- Name: idx_feed_posts_important; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feed_posts_important ON public.feed_posts USING btree (feed_id, is_important);


--
-- Name: idx_feeds_owner_group; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feeds_owner_group ON public.feeds USING btree (owner_group_id);


--
-- Name: idx_feeds_owner_type; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feeds_owner_type ON public.feeds USING btree (owner_type);


--
-- Name: idx_feeds_owner_user; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_feeds_owner_user ON public.feeds USING btree (owner_user_id);


--
-- Name: idx_group_hometask_assignments_group; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_group_hometask_assignments_group ON public.group_hometask_assignments USING btree (group_id);


--
-- Name: idx_group_hometask_assignments_teacher; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_group_hometask_assignments_teacher ON public.group_hometask_assignments USING btree (teacher_id);


--
-- Name: idx_group_student_group; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_group_student_group ON public.group_student_relations USING btree (group_id);


--
-- Name: idx_group_student_student; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_group_student_student ON public.group_student_relations USING btree (student_user_id);


--
-- Name: idx_hometask_submissions_hometask_id; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_hometask_submissions_hometask_id ON public.hometask_submissions USING btree (hometask_id);


--
-- Name: idx_hometask_submissions_student_id; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_hometask_submissions_student_id ON public.hometask_submissions USING btree (student_id);


--
-- Name: idx_hometasks_group_assignment_id; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_hometasks_group_assignment_id ON public.hometasks USING btree (group_assignment_id);


--
-- Name: idx_hometasks_next_reset_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_hometasks_next_reset_at ON public.hometasks USING btree (next_reset_at);


--
-- Name: idx_hometasks_status; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_hometasks_status ON public.hometasks USING btree (status);


--
-- Name: idx_hometasks_student_id; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_hometasks_student_id ON public.hometasks USING btree (student_id);


--
-- Name: idx_hometasks_teacher_id; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_hometasks_teacher_id ON public.hometasks USING btree (teacher_id);


--
-- Name: idx_media_files_created_by; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_media_files_created_by ON public.media_files USING btree (created_by_user_id);


--
-- Name: idx_media_files_type; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_media_files_type ON public.media_files USING btree (media_type);


--
-- Name: idx_message_receipts_message; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_message_receipts_message ON public.message_receipts USING btree (message_id);


--
-- Name: idx_message_receipts_recipient; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_message_receipts_recipient ON public.message_receipts USING btree (recipient_id);


--
-- Name: idx_message_receipts_state; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_message_receipts_state ON public.message_receipts USING btree (state);


--
-- Name: idx_notifications_body_gin; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_notifications_body_gin ON public.notifications USING gin (body);


--
-- Name: idx_notifications_created_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_notifications_created_at ON public.notifications USING btree (created_at DESC);


--
-- Name: idx_notifications_read_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_notifications_read_at ON public.notifications USING btree (read_at) WHERE (read_at IS NULL);


--
-- Name: idx_notifications_type; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_notifications_type ON public.notifications USING btree (type);


--
-- Name: idx_notifications_user_id; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_notifications_user_id ON public.notifications USING btree (user_id);


--
-- Name: idx_notifications_user_unread; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id, read_at) WHERE (read_at IS NULL);


--
-- Name: idx_parent_student_parent; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_parent_student_parent ON public.parent_student_relations USING btree (parent_user_id);


--
-- Name: idx_parent_student_student; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_parent_student_student ON public.parent_student_relations USING btree (student_user_id);


--
-- Name: idx_parents_archived_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_parents_archived_at ON public.parents USING btree (archived_at);


--
-- Name: idx_parents_status; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_parents_status ON public.parents USING btree (status);


--
-- Name: idx_password_reset_requests_username; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_password_reset_requests_username ON public.password_reset_requests USING btree (username);


--
-- Name: idx_password_reset_tokens_token_hash; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_password_reset_tokens_token_hash ON public.password_reset_tokens USING btree (token_hash);


--
-- Name: idx_push_tokens_revoked_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_push_tokens_revoked_at ON public.push_tokens USING btree (revoked_at) WHERE (revoked_at IS NULL);


--
-- Name: idx_push_tokens_user_id; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_push_tokens_user_id ON public.push_tokens USING btree (user_id);


--
-- Name: idx_registration_tokens_expires; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_registration_tokens_expires ON public.registration_tokens USING btree (expires_at);


--
-- Name: idx_registration_tokens_hash; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_registration_tokens_hash ON public.registration_tokens USING btree (token_hash);


--
-- Name: idx_registration_tokens_related_student; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_registration_tokens_related_student ON public.registration_tokens USING btree (related_student_id);


--
-- Name: idx_registration_tokens_related_teacher; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_registration_tokens_related_teacher ON public.registration_tokens USING btree (related_teacher_id);


--
-- Name: idx_student_groups_status; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_student_groups_status ON public.student_groups USING btree (status);


--
-- Name: idx_student_groups_teacher; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_student_groups_teacher ON public.student_groups USING btree (teacher_user_id);


--
-- Name: idx_students_archived_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_students_archived_at ON public.students USING btree (archived_at);


--
-- Name: idx_students_status; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_students_status ON public.students USING btree (status);


--
-- Name: idx_teacher_student_student; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_teacher_student_student ON public.teacher_student_relations USING btree (student_user_id);


--
-- Name: idx_teacher_student_teacher; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_teacher_student_teacher ON public.teacher_student_relations USING btree (teacher_user_id);


--
-- Name: idx_teachers_archived_at; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_teachers_archived_at ON public.teachers USING btree (archived_at);


--
-- Name: idx_teachers_status; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_teachers_status ON public.teachers USING btree (status);


--
-- Name: idx_users_full_name; Type: INDEX; Schema: public; Owner: klavier
--

CREATE INDEX idx_users_full_name ON public.users USING btree (full_name);


--
-- Name: chat_messages update_chat_messages_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_chat_messages_updated_at BEFORE UPDATE ON public.chat_messages FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: chat_threads update_chat_threads_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_chat_threads_updated_at BEFORE UPDATE ON public.chat_threads FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: feed_comments update_feed_comments_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_feed_comments_updated_at BEFORE UPDATE ON public.feed_comments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: feed_posts update_feed_posts_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_feed_posts_updated_at BEFORE UPDATE ON public.feed_posts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: group_hometask_assignments update_group_hometask_assignments_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_group_hometask_assignments_updated_at BEFORE UPDATE ON public.group_hometask_assignments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: hometasks update_hometasks_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_hometasks_updated_at BEFORE UPDATE ON public.hometasks FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: parents update_parents_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_parents_updated_at BEFORE UPDATE ON public.parents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: student_groups update_student_groups_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_student_groups_updated_at BEFORE UPDATE ON public.student_groups FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: students update_students_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_students_updated_at BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: teachers update_teachers_updated_at; Type: TRIGGER; Schema: public; Owner: klavier
--

CREATE TRIGGER update_teachers_updated_at BEFORE UPDATE ON public.teachers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: chat_message_attachments chat_message_attachments_media_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_message_attachments
    ADD CONSTRAINT chat_message_attachments_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_files(id) ON DELETE CASCADE;


--
-- Name: chat_message_attachments chat_message_attachments_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_message_attachments
    ADD CONSTRAINT chat_message_attachments_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.chat_messages(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.chat_threads(id) ON DELETE CASCADE;


--
-- Name: chat_presence chat_presence_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_presence
    ADD CONSTRAINT chat_presence_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: chat_threads chat_threads_participant_a_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_threads
    ADD CONSTRAINT chat_threads_participant_a_id_fkey FOREIGN KEY (participant_a_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: chat_threads chat_threads_participant_b_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.chat_threads
    ADD CONSTRAINT chat_threads_participant_b_id_fkey FOREIGN KEY (participant_b_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: feed_comment_media feed_comment_media_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_comment_media
    ADD CONSTRAINT feed_comment_media_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.feed_comments(id) ON DELETE CASCADE;


--
-- Name: feed_comment_media feed_comment_media_media_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_comment_media
    ADD CONSTRAINT feed_comment_media_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_files(id) ON DELETE CASCADE;


--
-- Name: feed_comments feed_comments_author_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_comments
    ADD CONSTRAINT feed_comments_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: feed_comments feed_comments_parent_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_comments
    ADD CONSTRAINT feed_comments_parent_comment_id_fkey FOREIGN KEY (parent_comment_id) REFERENCES public.feed_comments(id) ON DELETE CASCADE;


--
-- Name: feed_comments feed_comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_comments
    ADD CONSTRAINT feed_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.feed_posts(id) ON DELETE CASCADE;


--
-- Name: feed_post_media feed_post_media_media_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_post_media
    ADD CONSTRAINT feed_post_media_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_files(id) ON DELETE CASCADE;


--
-- Name: feed_post_media feed_post_media_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_post_media
    ADD CONSTRAINT feed_post_media_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.feed_posts(id) ON DELETE CASCADE;


--
-- Name: feed_post_reads feed_post_reads_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_post_reads
    ADD CONSTRAINT feed_post_reads_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.feed_posts(id) ON DELETE CASCADE;


--
-- Name: feed_post_reads feed_post_reads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_post_reads
    ADD CONSTRAINT feed_post_reads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: feed_post_subscriptions feed_post_subscriptions_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_post_subscriptions
    ADD CONSTRAINT feed_post_subscriptions_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.feed_posts(id) ON DELETE CASCADE;


--
-- Name: feed_post_subscriptions feed_post_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_post_subscriptions
    ADD CONSTRAINT feed_post_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: feed_posts feed_posts_author_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_posts
    ADD CONSTRAINT feed_posts_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: feed_posts feed_posts_feed_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_posts
    ADD CONSTRAINT feed_posts_feed_id_fkey FOREIGN KEY (feed_id) REFERENCES public.feeds(id) ON DELETE CASCADE;


--
-- Name: feed_settings feed_settings_feed_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_settings
    ADD CONSTRAINT feed_settings_feed_id_fkey FOREIGN KEY (feed_id) REFERENCES public.feeds(id) ON DELETE CASCADE;


--
-- Name: feed_user_settings feed_user_settings_feed_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_user_settings
    ADD CONSTRAINT feed_user_settings_feed_id_fkey FOREIGN KEY (feed_id) REFERENCES public.feeds(id) ON DELETE CASCADE;


--
-- Name: feed_user_settings feed_user_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feed_user_settings
    ADD CONSTRAINT feed_user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: feeds feeds_owner_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feeds
    ADD CONSTRAINT feeds_owner_group_id_fkey FOREIGN KEY (owner_group_id) REFERENCES public.student_groups(id) ON DELETE SET NULL;


--
-- Name: feeds feeds_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.feeds
    ADD CONSTRAINT feeds_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES public.teachers(user_id) ON DELETE SET NULL;


--
-- Name: parent_student_relations fk_parent; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.parent_student_relations
    ADD CONSTRAINT fk_parent FOREIGN KEY (parent_user_id) REFERENCES public.parents(user_id) ON DELETE CASCADE;


--
-- Name: parent_student_relations fk_student; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.parent_student_relations
    ADD CONSTRAINT fk_student FOREIGN KEY (student_user_id) REFERENCES public.students(user_id) ON DELETE CASCADE;


--
-- Name: group_hometask_assignments group_hometask_assignments_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.group_hometask_assignments
    ADD CONSTRAINT group_hometask_assignments_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.student_groups(id) ON DELETE CASCADE;


--
-- Name: group_hometask_assignments group_hometask_assignments_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.group_hometask_assignments
    ADD CONSTRAINT group_hometask_assignments_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_student_relations group_student_relations_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.group_student_relations
    ADD CONSTRAINT group_student_relations_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.student_groups(id) ON DELETE CASCADE;


--
-- Name: group_student_relations group_student_relations_student_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.group_student_relations
    ADD CONSTRAINT group_student_relations_student_user_id_fkey FOREIGN KEY (student_user_id) REFERENCES public.students(user_id) ON DELETE CASCADE;


--
-- Name: hometask_submissions hometask_submissions_hometask_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometask_submissions
    ADD CONSTRAINT hometask_submissions_hometask_id_fkey FOREIGN KEY (hometask_id) REFERENCES public.hometasks(id) ON DELETE CASCADE;


--
-- Name: hometask_submissions hometask_submissions_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometask_submissions
    ADD CONSTRAINT hometask_submissions_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: hometasks hometasks_group_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometasks
    ADD CONSTRAINT hometasks_group_assignment_id_fkey FOREIGN KEY (group_assignment_id) REFERENCES public.group_hometask_assignments(id) ON DELETE SET NULL;


--
-- Name: hometasks hometasks_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometasks
    ADD CONSTRAINT hometasks_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: hometasks hometasks_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.hometasks
    ADD CONSTRAINT hometasks_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: media_files media_files_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.media_files
    ADD CONSTRAINT media_files_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: message_receipts message_receipts_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.message_receipts
    ADD CONSTRAINT message_receipts_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.chat_messages(id) ON DELETE CASCADE;


--
-- Name: message_receipts message_receipts_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.message_receipts
    ADD CONSTRAINT message_receipts_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: parent_student_relations parent_student_relations_parent_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.parent_student_relations
    ADD CONSTRAINT parent_student_relations_parent_user_id_fkey FOREIGN KEY (parent_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: parent_student_relations parent_student_relations_student_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.parent_student_relations
    ADD CONSTRAINT parent_student_relations_student_user_id_fkey FOREIGN KEY (student_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: parents parents_archived_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.parents
    ADD CONSTRAINT parents_archived_by_fkey FOREIGN KEY (archived_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: parents parents_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.parents
    ADD CONSTRAINT parents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: password_reset_requests password_reset_requests_resolved_by_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.password_reset_requests
    ADD CONSTRAINT password_reset_requests_resolved_by_admin_id_fkey FOREIGN KEY (resolved_by_admin_id) REFERENCES public.users(id);


--
-- Name: password_reset_tokens password_reset_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: push_tokens push_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.push_tokens
    ADD CONSTRAINT push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: registration_tokens registration_tokens_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.registration_tokens
    ADD CONSTRAINT registration_tokens_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: registration_tokens registration_tokens_related_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.registration_tokens
    ADD CONSTRAINT registration_tokens_related_student_id_fkey FOREIGN KEY (related_student_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: registration_tokens registration_tokens_related_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.registration_tokens
    ADD CONSTRAINT registration_tokens_related_teacher_id_fkey FOREIGN KEY (related_teacher_id) REFERENCES public.teachers(user_id) ON DELETE CASCADE;


--
-- Name: registration_tokens registration_tokens_used_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.registration_tokens
    ADD CONSTRAINT registration_tokens_used_by_user_id_fkey FOREIGN KEY (used_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: student_groups student_groups_teacher_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.student_groups
    ADD CONSTRAINT student_groups_teacher_user_id_fkey FOREIGN KEY (teacher_user_id) REFERENCES public.teachers(user_id) ON DELETE CASCADE;


--
-- Name: students students_archived_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_archived_by_fkey FOREIGN KEY (archived_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: students students_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: teacher_student_relations teacher_student_relations_student_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.teacher_student_relations
    ADD CONSTRAINT teacher_student_relations_student_user_id_fkey FOREIGN KEY (student_user_id) REFERENCES public.students(user_id) ON DELETE CASCADE;


--
-- Name: teacher_student_relations teacher_student_relations_teacher_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.teacher_student_relations
    ADD CONSTRAINT teacher_student_relations_teacher_user_id_fkey FOREIGN KEY (teacher_user_id) REFERENCES public.teachers(user_id) ON DELETE CASCADE;


--
-- Name: teachers teachers_archived_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_archived_by_fkey FOREIGN KEY (archived_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: teachers teachers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: klavier
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict qinhTVVbXTKCVCXruK6cAaaANkZfDVy9slcc8ysDAqAG2PGJZSygKOkGihDrcqg

