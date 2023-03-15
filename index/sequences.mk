DATABASE ?= philomena
ELASTICDUMP ?= elasticdump
.ONESHELL:

all: import_es

import_es: dump_jsonl
	$(ELASTICDUMP) --input=sequences.jsonl --output=http://localhost:9200/ --output-index=sequences --limit 10000 --retryAttempts=5 --type=data --transform="doc._source = Object.assign({},doc)"

dump_jsonl: metadata subscribers images
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'copy (select temp_sequences.jsonb_object_agg(object) from temp_sequences.sequence_search_json group by sequence_id) to stdout;' > sequences.jsonl
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'drop schema temp_sequences cascade;'
	sed -i sequences.jsonl -e 's/\\\\/\\/g'

metadata: sequence_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_sequences.sequence_search_json (sequence_id, object) select g.id, jsonb_build_object(
			'id', g.id,
			'image_count', g.image_count,
			'updated_at', g.updated_at,
			'created_at', g.created_at,
			'title', lower(g.title),
			'creator', lower(u.name),
			'description', g.description
		) from sequences g left join users u on g.creator_id=u.id;
	SQL

subscribers: sequence_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_sequences.sequence_search_json (sequence_id, object) select sequence_id, json_build_object('watcher_ids', jsonb_agg(user_id), 'watcher_count', count(*)) from sequence_subscriptions group by sequence_id;
	SQL

images: sequence_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_sequences.sequence_search_json (sequence_id, object) select sequence_id, json_build_object('image_ids', jsonb_agg(image_id)) from sequence_interactions group by sequence_id;
	SQL

sequence_search_json:
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		drop schema if exists temp_sequences cascade;
		create schema temp_sequences;
		create unlogged table temp_sequences.sequence_search_json (sequence_id bigint not null, object jsonb not null);
		create or replace aggregate temp_sequences.jsonb_object_agg(jsonb) (sfunc = 'jsonb_concat', stype = jsonb, initcond='{}');
	SQL
