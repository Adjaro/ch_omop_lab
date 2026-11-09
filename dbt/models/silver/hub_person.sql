-- Hub d'identité patient : un person_id STABLE par IPP, attribué une seule fois.
-- Insertion seule ; seuls les IPP jamais vus reçoivent un nouvel identifiant (max + rang).
-- Un seul écrivain (dbt) => pas de collision. Les releases OMOP restent comparables entre elles.
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    order_by='source_key'
) }}

with nouveaux as (
    select pat_ipp as source_key, min(_batch_id) as first_batch_id
    from {{ ref('bz_pa_pat') }}
    where _batch_id > {{ batch_watermark('first_batch_id') }}
    {% if is_incremental() %}
      and pat_ipp not in (select source_key from {{ this }})
    {% endif %}
    group by pat_ipp
)
select
    toInt32({{ max_id('person_id') }} + row_number() over (order by source_key)) as person_id,
    source_key,
    first_batch_id,
    now() as assigned_at
from nouveaux
