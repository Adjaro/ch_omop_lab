-- Prescriptions canoniques (incrémental par lot)
-- depends_on: {{ ref('dict_vocab') }}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    engine='ReplacingMergeTree(_batch_id)',
    order_by='presc_id'
) }}

select
    toInt32(p.presc_id)                      as presc_id,
    s.person_id                               as person_id,
    s.visit_occurrence_id                     as visit_occurrence_id,
    p.code_ucd                                as code_ucd,
    p.dose                                    as dose,
    p.voie                                    as voie,
    p.date_debut                              as date_debut,
    p.date_fin                                as date_fin,
    {{ vocab_concept('UCD', 'p.code_ucd') }} as concept_id,
    p._batch_id                               as _batch_id
from {{ ref('bz_pharma') }} p
inner join {{ ref('slv_stay') }} s on s.pas_ips = p.pas_ips
where p._batch_id > {{ batch_watermark() }}
