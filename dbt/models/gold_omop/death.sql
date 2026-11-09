-- OMOP DEATH — à partir de la dernière version du patient
{{ config(order_by='person_id') }}

select
    toInt32(person_id)                              as person_id,
    toDate(date_deces)                              as death_date,
    CAST(NULL, 'Nullable(DateTime)')                as death_datetime,
    CAST({{ var('type_concept_ehr') }}, 'Nullable(Int32)') as death_type_concept_id,
    CAST(0, 'Nullable(Int32)')                      as cause_concept_id,
    CAST(NULL, 'Nullable(String)')                  as cause_source_value,
    CAST(NULL, 'Nullable(Int32)')                   as cause_source_concept_id,
    {{ gold_tech_columns() }}
from {{ ref('slv_patient') }}
where date_deces is not null and not is_opposed
  and person_id in (select person_id from {{ ref('slv_stay') }})
