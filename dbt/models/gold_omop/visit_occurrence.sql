-- OMOP VISIT_OCCURRENCE — reconstruit à chaque run (les corrections d'UF sont ainsi toujours prises en compte)
-- HC -> 9201 Inpatient, URG -> 9203 Emergency Room, CS/HJ -> 9202 Outpatient
{{ config(
    order_by='visit_occurrence_id',
    indexes=[{'name': 'idx_person', 'definition': 'person_id TYPE bloom_filter(0.01) GRANULARITY 4'}]
) }}

select
    toInt32(s.visit_occurrence_id)                                         as visit_occurrence_id,
    toInt32(s.person_id)                                                   as person_id,
    toInt32(multiIf(s.type_sejour = 'HC', 9201, s.type_sejour = 'URG', 9203, 9202)) as visit_concept_id,
    toDate(s.start_dt)                                                     as visit_start_date,
    CAST(s.start_dt, 'Nullable(DateTime)')                                 as visit_start_datetime,
    toDate(coalesce(s.end_dt, now()))                                      as visit_end_date,
    CAST(s.end_dt, 'Nullable(DateTime)')                                   as visit_end_datetime,
    toInt32({{ var('type_concept_ehr') }})                                 as visit_type_concept_id,
    CAST(NULL, 'Nullable(Int32)')                                          as provider_id,
    CAST(s.uf_med, 'Nullable(Int32)')                                      as care_site_id,
    CAST(s.type_sejour, 'Nullable(String)')                                as visit_source_value,
    CAST(0, 'Nullable(Int32)')                                             as visit_source_concept_id,
    CAST(0, 'Nullable(Int32)')                                             as admitted_from_concept_id,
    CAST(s.mode_entree, 'Nullable(String)')                                as admitted_from_source_value,
    CAST(0, 'Nullable(Int32)')                                             as discharged_to_concept_id,
    CAST(s.mode_sortie, 'Nullable(String)')                                as discharged_to_source_value,
    CAST(NULL, 'Nullable(Int32)')                                          as preceding_visit_occurrence_id,
    {{ gold_tech_columns() }}
from {{ ref('slv_stay') }} s
where s.person_id not in (select person_id from {{ ref('slv_patient') }} where is_opposed)
