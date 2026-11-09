-- OMOP MEASUREMENT — incrémental par lot + suppression logique (oppositions)
-- Tri (measurement_concept_id, person_id, id) : les cohortes filtrent par concept => lecture de quelques blocs seulement,
-- et forte compression. Clé de déduplication stable : un id garde son concept et sa personne
-- (hubs d'identité). Après un changement de mapping des vocabulaires : dbt build --full-refresh.
-- depends_on: {{ ref('slv_patient') }}, {{ ref('slv_opposition') }}, {{ ref('hub_person') }}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    order_by='(measurement_concept_id, person_id, measurement_id)',
    indexes=[{'name': 'idx_person', 'definition': 'person_id TYPE bloom_filter(0.01) GRANULARITY 4'}]
) }}
{%- set wm = batch_watermark('_src_batch_id') %}

{{ gold_event_source(ref('slv_bio'), wm) }}
select
    bio_id                                          as measurement_id,
    person_id,
    toInt32(concept_id)                             as measurement_concept_id,
    toDate(date_prel)                               as measurement_date,
    CAST(date_prel, 'Nullable(DateTime)')           as measurement_datetime,
    CAST(formatDateTime(date_prel, '%H:%i:%S'), 'Nullable(String)') as measurement_time,
    toInt32({{ var('type_concept_ehr') }})          as measurement_type_concept_id,
    CAST(NULL, 'Nullable(Int32)')                   as operator_concept_id,
    CAST(valeur, 'Nullable(Decimal(12, 3))')        as value_as_number,
    CAST(NULL, 'Nullable(Int32)')                   as value_as_concept_id,
    CAST(0, 'Nullable(Int32)')                      as unit_concept_id,
    CAST(borne_inf, 'Nullable(Decimal(12, 3))')     as range_low,
    CAST(borne_sup, 'Nullable(Decimal(12, 3))')     as range_high,
    CAST(NULL, 'Nullable(Int32)')                   as provider_id,
    CAST(visit_occurrence_id, 'Nullable(Int32)')    as visit_occurrence_id,
    CAST(NULL, 'Nullable(Int32)')                   as visit_detail_id,
    CAST(code_analyse, 'Nullable(String)')          as measurement_source_value,
    CAST(0, 'Nullable(Int32)')                      as measurement_source_concept_id,
    CAST(unite, 'Nullable(String)')                 as unit_source_value,
    CAST(NULL, 'Nullable(Int32)')                   as unit_source_concept_id,
    CAST(toString(valeur), 'Nullable(String)')      as value_source_value,
    CAST(NULL, 'Nullable(Int64)')                   as measurement_event_id,
    CAST(NULL, 'Nullable(Int32)')                   as meas_event_field_concept_id,
    _batch_id                                       as _src_batch_id,
    {{ gold_tech_columns('del') }}
from src
