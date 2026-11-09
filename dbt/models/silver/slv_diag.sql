-- Diagnostics canoniques (incrémental par lot) : rattachés au séjour + concept mappé via dictionnaire
-- depends_on: {{ ref('dict_vocab') }}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    engine='ReplacingMergeTree(_batch_id)',
    order_by='diag_id'
) }}

select
    toInt32(d.diag_id)                        as diag_id,
    s.person_id                               as person_id,
    s.visit_occurrence_id                     as visit_occurrence_id,
    d.code_cim10                              as code_cim10,
    d.type_diag                               as type_diag,
    d.date_diag                               as date_diag,
    s.start_dt                                as start_dt,
    s.end_dt                                  as end_dt,
    {{ vocab_concept('CIM10', 'd.code_cim10') }} as concept_id,
    d._batch_id                               as _batch_id
from {{ ref('bz_diag') }} d
inner join {{ ref('slv_stay') }} s on s.pas_ips = d.pas_ips
where d._batch_id > {{ batch_watermark() }}
