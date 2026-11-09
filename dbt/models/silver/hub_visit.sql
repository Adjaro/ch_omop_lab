-- Hub d'identité séjour : un visit_occurrence_id STABLE par IEP (épisode).
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    order_by='source_key'
) }}

with nouveaux as (
    select iep_ide as source_key, min(_batch_id) as first_batch_id
    from {{ ref('bz_pa_pas') }}
    where _batch_id > {{ batch_watermark('first_batch_id') }}
    {% if is_incremental() %}
      and iep_ide not in (select source_key from {{ this }})
    {% endif %}
    group by iep_ide
)
select
    toInt32({{ max_id('visit_occurrence_id') }} + row_number() over (order by source_key)) as visit_occurrence_id,
    source_key,
    first_batch_id,
    now() as assigned_at
from nouveaux
