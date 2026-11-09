-- OMOP PERSON — reconstruit à chaque run (quelques secondes dans ClickHouse)
-- person_source_value = pseudonyme (SHA-256 tronqué de l'IPP), jamais l'IPP en clair.
{{ config(order_by='person_id') }}

select
    toInt32(person_id)                                          as person_id,
    toInt32(multiIf(sexe = 'F', 8532, sexe = 'M', 8507, 0))     as gender_concept_id,
    toInt32(toYear(date_naiss))                                 as year_of_birth,
    CAST(toMonth(date_naiss), 'Nullable(Int32)')                as month_of_birth,
    CAST(toDayOfMonth(date_naiss), 'Nullable(Int32)')           as day_of_birth,
    CAST(NULL, 'Nullable(DateTime)')                            as birth_datetime,
    toInt32(0)                                                  as race_concept_id,
    toInt32(0)                                                  as ethnicity_concept_id,
    CAST(NULL, 'Nullable(Int32)')                               as location_id,
    CAST(NULL, 'Nullable(Int32)')                               as provider_id,
    CAST(NULL, 'Nullable(Int32)')                               as care_site_id,
    CAST(substring(lower(hex(SHA256(toString(pat_ipp)))), 1, 32), 'Nullable(String)') as person_source_value,
    CAST(sexe, 'Nullable(String)')                              as gender_source_value,
    CAST(0, 'Nullable(Int32)')                                  as gender_source_concept_id,
    CAST(NULL, 'Nullable(String)')                              as race_source_value,
    CAST(NULL, 'Nullable(Int32)')                               as race_source_concept_id,
    CAST(NULL, 'Nullable(String)')                              as ethnicity_source_value,
    CAST(NULL, 'Nullable(Int32)')                               as ethnicity_source_concept_id,
    {{ gold_tech_columns() }}
from {{ ref('slv_patient') }}
where not is_opposed
  -- convention OMOP : une personne n'entre dans le CDM qu'avec au moins une période d'observation
  and person_id in (select person_id from {{ ref('slv_stay') }})
