-- OMOP OBSERVATION_PERIOD — une période par personne : de la première à la dernière visite
{{ config(order_by='observation_period_id') }}

select
    toInt32(person_id)                         as observation_period_id,
    toInt32(person_id)                         as person_id,
    min(visit_start_date)                      as observation_period_start_date,
    max(visit_end_date)                        as observation_period_end_date,
    toInt32({{ var('type_concept_ehr') }})     as period_type_concept_id,
    {{ gold_tech_columns() }}
from {{ ref('visit_occurrence') }} final
where _is_deleted = 0
group by person_id
