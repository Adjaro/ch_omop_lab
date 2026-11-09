-- Actes canoniques (incrémental par lot)
-- depends_on: {{ ref('dict_vocab') }}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    engine='ReplacingMergeTree(_batch_id)',
    order_by='acte_id'
) }}

select
    toInt32(a.acte_id)                       as acte_id,
    s.person_id                               as person_id,
    s.visit_occurrence_id                     as visit_occurrence_id,
    a.code_ccam                               as code_ccam,
    a.date_acte                               as date_acte,
    {{ vocab_concept('CCAM', 'a.code_ccam') }} as concept_id,
    a._batch_id                               as _batch_id
from {{ ref('bz_actes') }} a
inner join {{ ref('slv_stay') }} s on s.pas_ips = a.pas_ips
where a._batch_id > {{ batch_watermark() }}
