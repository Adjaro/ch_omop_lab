-- OMOP DRUG_EXPOSURE — incrémental par lot + suppression logique (oppositions)
-- Tri (drug_concept_id, person_id, id) : les cohortes filtrent par concept => lecture de quelques blocs seulement,
-- et forte compression. Clé de déduplication stable : un id garde son concept et sa personne
-- (hubs d'identité). Après un changement de mapping des vocabulaires : dbt build --full-refresh.
-- depends_on: {{ ref('slv_patient') }}, {{ ref('slv_opposition') }}, {{ ref('hub_person') }}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    order_by='(drug_concept_id, person_id, drug_exposure_id)',
    indexes=[{'name': 'idx_person', 'definition': 'person_id TYPE bloom_filter(0.01) GRANULARITY 4'}]
) }}
{%- set wm = batch_watermark('_src_batch_id') %}

{{ gold_event_source(ref('slv_presc'), wm) }}
select
    presc_id                                                    as drug_exposure_id,
    person_id,
    toInt32(concept_id)                                         as drug_concept_id,
    toDate(date_debut)                                          as drug_exposure_start_date,
    CAST(date_debut, 'Nullable(DateTime)')                      as drug_exposure_start_datetime,
    toDate(coalesce(date_fin, date_debut))                      as drug_exposure_end_date,
    CAST(date_fin, 'Nullable(DateTime)')                        as drug_exposure_end_datetime,
    CAST(NULL, 'Nullable(Date)')                                as verbatim_end_date,
    toInt32({{ var('type_concept_ehr') }})                      as drug_type_concept_id,
    CAST(NULL, 'Nullable(String)')                              as stop_reason,
    CAST(NULL, 'Nullable(Int32)')                               as refills,
    CAST(NULL, 'Nullable(Decimal(10, 2))')                      as quantity,
    CAST(dateDiff('day', toDate(date_debut), toDate(coalesce(date_fin, date_debut))) + 1, 'Nullable(Int32)') as days_supply,
    CAST(concat(toString(dose), ' / ', voie), 'Nullable(String)') as sig,
    CAST(0, 'Nullable(Int32)')                                  as route_concept_id,
    CAST(NULL, 'Nullable(String)')                              as lot_number,
    CAST(NULL, 'Nullable(Int32)')                               as provider_id,
    CAST(visit_occurrence_id, 'Nullable(Int32)')                as visit_occurrence_id,
    CAST(NULL, 'Nullable(Int32)')                               as visit_detail_id,
    CAST(code_ucd, 'Nullable(String)')                          as drug_source_value,
    CAST(0, 'Nullable(Int32)')                                  as drug_source_concept_id,
    CAST(voie, 'Nullable(String)')                              as route_source_value,
    CAST(NULL, 'Nullable(String)')                              as dose_unit_source_value,
    _batch_id                                                   as _src_batch_id,
    {{ gold_tech_columns('del') }}
from src
