-- Diagnostics par année : nombre d'occurrences et de patients distincts
-- depends_on: {{ ref('dict_vocab') }}
{{ config(order_by='(annee, code_cim10)') }}

{%- set d = ref('dict_vocab') %}
select
    toYear(condition_start_date)                                    as annee,
    assumeNotNull(condition_source_value)                           as code_cim10,
    dictGetOrDefault('{{ d.schema }}.{{ d.identifier }}', 'source_label',
                     tuple('CIM10', code_cim10), '')                as libelle,
    countIf(condition_status_source_value = 'DP')                   as nb_dp,
    count()                                                         as nb_total,
    uniqExact(person_id)                                            as nb_patients
from {{ ref('condition_occurrence') }} final
where _is_deleted = 0
group by annee, code_cim10
