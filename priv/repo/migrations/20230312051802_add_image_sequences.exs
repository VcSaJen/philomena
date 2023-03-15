defmodule Philomena.Repo.Migrations.AddImageSequences do
  use Ecto.Migration

  def up do
    execute("""
      CREATE TABLE public.sequences (
          id integer NOT NULL,
          title character varying NOT NULL,
          spoiler_warning character varying DEFAULT ''::character varying NOT NULL,
          description character varying DEFAULT ''::character varying NOT NULL,
          thumbnail_id integer NOT NULL,
          creator_id integer NOT NULL,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL,
          watcher_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
          watcher_count integer DEFAULT 0 NOT NULL,
          image_count integer DEFAULT 0 NOT NULL,
          order_position_asc boolean DEFAULT false NOT NULL
      );
    """)
    execute("""
      CREATE SEQUENCE public.sequences_id_seq
          START WITH 1
          INCREMENT BY 1
          NO MINVALUE
          NO MAXVALUE
          CACHE 1;
    """)
    execute("""
      ALTER SEQUENCE public.sequences_id_seq OWNED BY public.sequences.id;
    """)
    execute("""
      CREATE TABLE public.sequence_interactions (
          id integer NOT NULL,
          "position" integer NOT NULL,
          image_id integer NOT NULL,
          sequence_id integer NOT NULL
      );
    """)
    execute("""
      CREATE SEQUENCE public.sequence_interactions_id_seq
          START WITH 1
          INCREMENT BY 1
          NO MINVALUE
          NO MAXVALUE
          CACHE 1;
    """)
    execute("""
      ALTER SEQUENCE public.sequence_interactions_id_seq OWNED BY public.sequence_interactions.id;
    """)
    execute("""
      CREATE TABLE public.sequence_subscriptions (
          sequence_id integer NOT NULL,
          user_id integer NOT NULL
      );
    """)
    execute("""
      ALTER TABLE ONLY public.sequences ALTER COLUMN id SET DEFAULT nextval('public.sequences_id_seq'::regclass);
    """)
    execute("""
      ALTER TABLE ONLY public.sequence_interactions ALTER COLUMN id SET DEFAULT nextval('public.sequence_interactions_id_seq'::regclass);
    """)
    execute("""
      ALTER TABLE ONLY public.sequences
          ADD CONSTRAINT sequences_pkey PRIMARY KEY (id);
    """)
    execute("""
      ALTER TABLE ONLY public.sequence_interactions
          ADD CONSTRAINT sequence_interactions_pkey PRIMARY KEY (id);
    """)
    execute("""
      CREATE INDEX index_sequences_on_creator_id ON public.sequences USING btree (creator_id);
    """)
    execute("""
      CREATE INDEX index_sequences_on_thumbnail_id ON public.sequences USING btree (thumbnail_id);
    """)
    execute("""
      CREATE INDEX index_sequence_interactions_on_sequence_id ON public.sequence_interactions USING btree (sequence_id);
    """)
    execute("""
      CREATE UNIQUE INDEX index_sequence_interactions_on_sequence_id_and_image_id ON public.sequence_interactions USING btree (sequence_id, image_id);
    """)
    execute("""
      CREATE INDEX index_sequence_interactions_on_sequence_id_and_position ON public.sequence_interactions USING btree (sequence_id, "position");
    """)
    execute("""
      CREATE INDEX index_sequence_interactions_on_image_id ON public.sequence_interactions USING btree (image_id);
    """)
    execute("""
      CREATE INDEX index_sequence_interactions_on_position ON public.sequence_interactions USING btree ("position");
    """)
    execute("""
      CREATE UNIQUE INDEX index_sequence_subscriptions_on_sequence_id_and_user_id ON public.sequence_subscriptions USING btree (sequence_id, user_id);
    """)
    execute("""
      CREATE INDEX index_sequence_subscriptions_on_user_id ON public.sequence_subscriptions USING btree (user_id);
    """)
    execute("""
      ALTER TABLE ONLY public.sequence_interactions
          ADD CONSTRAINT sequence_interactions_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.sequences(id) ON UPDATE CASCADE ON DELETE CASCADE;
    """)
    execute("""
      ALTER TABLE ONLY public.sequences
          ADD CONSTRAINT sequences_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;
    """)
    execute("""
      ALTER TABLE ONLY public.sequence_subscriptions
          ADD CONSTRAINT sequence_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;
    """)
    execute("""
      ALTER TABLE ONLY public.sequences
          ADD CONSTRAINT sequences_thumbnail_id_fkey FOREIGN KEY (thumbnail_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE RESTRICT;
    """)
    execute("""
      ALTER TABLE ONLY public.sequence_interactions
          ADD CONSTRAINT sequence_interactions_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE RESTRICT;
    """)
    execute("""
      ALTER TABLE ONLY public.sequence_subscriptions
          ADD CONSTRAINT sequence_subscriptions_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.sequences(id) ON UPDATE CASCADE ON DELETE CASCADE;
    """)
  end

  def down do
    execute("DROP TABLE public.sequences;")
    execute("DROP TABLE public.sequence_interactions;")
    execute("DROP TABLE public.sequence_subscriptions;")
  end
end
