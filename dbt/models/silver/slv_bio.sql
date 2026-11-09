-- Résultats de biologie canoniques (incrémental par lot) — la plus grosse table du lab
-- depends_on: {{ ref('dict_vocab') }}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    engine='ReplacingMergeTree(_batch_id)',
    order_by='bio_id'
) }}

select
    toInt32(b.bio_id)                          as bio_id,
    s.person_id                               as person_id,
    s.visit_occurrence_id                     as visit_occurrence_id,
    b.code_analyse                            as code_analyse,
    b.valeur                                  as valeur,
    b.unite                                   as unite,
    b.borne_inf                               as borne_inf,
    b.borne_sup                               as borne_sup,
    b.date_prel                               as date_prel,
    {{ vocab_concept('BIO', 'b.code_analyse') }} as concept_id,
    b._batch_id                               as _batch_id
from {{ ref('bz_bio') }} b
inner join {{ ref('slv_stay') }} s on s.pas_ips = b.pas_ips
where b._batch_id > {{ batch_watermark() }}
