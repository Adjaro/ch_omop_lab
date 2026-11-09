-- Référentiel de mapping (petit) : rechargé entièrement à chaque run.
{{ config(materialized='table', order_by='(source_vocab, source_code)') }}

select * from postgresql({{ var('pg_collection') }}, table = 'ref_vocab_map')
