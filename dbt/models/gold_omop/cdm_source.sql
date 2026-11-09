-- OMOP CDM_SOURCE — métadonnées de la base (mises à jour à chaque run, publiées avec la release)
{{ config(order_by='cdm_source_abbreviation') }}

select
    '{{ var("cdm_source_name") }}'               as cdm_source_name,
    'CH_OMOP_LAB'                                as cdm_source_abbreviation,
    'Lab personnel'                              as cdm_holder,
    CAST('Données 100 % fictives générées dans Postgres, transformées dans ClickHouse (dbt)', 'Nullable(String)') as source_description,
    CAST(NULL, 'Nullable(String)')               as source_documentation_reference,
    CAST('dbt-clickhouse ch_omop_lab', 'Nullable(String)') as cdm_etl_reference,
    today()                                      as source_release_date,
    today()                                      as cdm_release_date,
    CAST('v5.4', 'Nullable(String)')             as cdm_version,
    toInt32({{ var('cdm_version_concept_id') }}) as cdm_version_concept_id,
    '{{ var("vocabulary_version") }}'            as vocabulary_version,
    {{ gold_tech_columns() }}
