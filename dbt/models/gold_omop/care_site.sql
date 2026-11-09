-- OMOP CARE_SITE — une ligne par unité fonctionnelle (UF)
{{ config(order_by='care_site_id') }}

select
    toInt32OrZero(source_code)                 as care_site_id,
    CAST(source_label, 'Nullable(String)')     as care_site_name,
    CAST(0, 'Nullable(Int32)')                 as place_of_service_concept_id,
    CAST(NULL, 'Nullable(Int32)')              as location_id,
    CAST(source_code, 'Nullable(String)')      as care_site_source_value,
    CAST(NULL, 'Nullable(String)')             as place_of_service_source_value,
    {{ gold_tech_columns() }}
from {{ ref('slv_vocab_map') }}
where source_vocab = 'UF'
