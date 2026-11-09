-- Statistiques mensuelles de biologie : volumes, moyenne, médiane, P95, % hors normes
-- depends_on: {{ ref('dict_vocab') }}
{{ config(order_by='(mois, code_analyse)') }}

{%- set d = ref('dict_vocab') %}
select
    toStartOfMonth(measurement_date)                               as mois,
    assumeNotNull(measurement_source_value)                        as code_analyse,
    dictGetOrDefault('{{ d.schema }}.{{ d.identifier }}', 'source_label',
                     tuple('BIO', code_analyse), '')               as libelle,
    count()                                                        as nb_resultats,
    uniqExact(person_id)                                           as nb_patients,
    round(avg(toFloat64(value_as_number)), 3)                      as moyenne,
    round(quantile(0.5)(toFloat64(value_as_number)), 3)           as mediane,
    round(quantile(0.95)(toFloat64(value_as_number)), 3)          as p95,
    round(100 * countIf(value_as_number < range_low or value_as_number > range_high) / count(), 2) as pct_hors_normes
from {{ ref('measurement') }} final
where _is_deleted = 0
group by mois, code_analyse
