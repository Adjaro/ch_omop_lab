-- OMOP CONDITION_OCCURRENCE — incrémental par lot + suppression logique (oppositions)
-- Tri (condition_concept_id, person_id, id) : les cohortes filtrent par concept => lecture de quelques blocs seulement,
-- et forte compression. Clé de déduplication stable : un id garde son concept et sa personne
-- (hubs d'identité). Après un changement de mapping des vocabulaires : dbt build --full-refresh.
-- depends_on: {{ ref('slv_patient') }}, {{ ref('slv_opposition') }}, {{ ref('hub_person') }}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    order_by='(condition_concept_id, person_id, condition_occurrence_id)',
    indexes=[{'name': 'idx_person', 'definition': 'person_id TYPE bloom_filter(0.01) GRANULARITY 4'}]
) }}
{%- set wm = batch_watermark('_src_batch_id') %}

{{ gold_event_source(ref('slv_diag'), wm) }}
select
    diag_id                                        as condition_occurrence_id,
    person_id,
    toInt32(concept_id)                            as condition_concept_id,
    toDate(date_diag)                              as condition_start_date,
    CAST(start_dt, 'Nullable(DateTime)')           as condition_start_datetime,
    CAST(NULL, 'Nullable(Date)')                   as condition_end_date,
    CAST(NULL, 'Nullable(DateTime)')               as condition_end_datetime,
    toInt32({{ var('type_concept_ehr') }})         as condition_type_concept_id,
    CAST(0, 'Nullable(Int32)')                     as condition_status_concept_id,
    CAST(NULL, 'Nullable(String)')                 as stop_reason,
    CAST(NULL, 'Nullable(Int32)')                  as provider_id,
    CAST(visit_occurrence_id, 'Nullable(Int32)')   as visit_occurrence_id,
    CAST(NULL, 'Nullable(Int32)')                  as visit_detail_id,
    CAST(code_cim10, 'Nullable(String)')           as condition_source_value,
    CAST(0, 'Nullable(Int32)')                     as condition_source_concept_id,
    CAST(type_diag, 'Nullable(String)')            as condition_status_source_value,
    _batch_id                                      as _src_batch_id,
    {{ gold_tech_columns('del') }}
from src
