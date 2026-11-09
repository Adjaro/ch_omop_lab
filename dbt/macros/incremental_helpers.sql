{#
  Watermark incrémental : plus grand numéro de lot déjà chargé dans la table cible.
  Valeur littérale (calculée par dbt avant la requête) => le filtre est poussé tel quel
  vers Postgres par la fonction postgresql() et n'importe que les nouvelles lignes.
#}
{% macro batch_watermark(column='_batch_id') -%}
  {%- if execute and is_incremental() -%}
    {%- set res = run_query('select coalesce(max(' ~ column ~ '), 0) from ' ~ this) -%}
    {{- res.columns[0].values()[0] | int -}}
  {%- else -%}0{%- endif -%}
{%- endmacro %}

{# Plus grand identifiant déjà attribué dans un hub (0 au premier run) #}
{% macro max_id(column) -%}
  {%- if execute and is_incremental() -%}
    {%- set res = run_query('select coalesce(max(' ~ column ~ '), 0) from ' ~ this) -%}
    {{- res.columns[0].values()[0] | int -}}
  {%- else -%}0{%- endif -%}
{%- endmacro %}

{# Réplication incrémentale d'une table du bronze Postgres via la named collection #}
{% macro replicate_from_pg(pg_table) -%}
select *
from postgresql({{ var('pg_collection') }}, table = '{{ pg_table }}')
where _batch_id > {{ batch_watermark('_batch_id') }}
{%- endmacro %}

{# Mapping code source -> concept_id via le dictionnaire en mémoire (0 si non mappé) #}
{% macro vocab_concept(vocab, code_expr) -%}
  {%- set d = ref('dict_vocab') -%}
  dictGetOrDefault('{{ d.schema }}.{{ d.identifier }}', 'target_concept_id', tuple('{{ vocab }}', toString({{ code_expr }})), toUInt32(0))
{%- endmacro %}

{# Colonnes techniques communes du gold (version de ligne + suppression logique) #}
{% macro gold_tech_columns(is_deleted='0') -%}
  toUInt64(toUnixTimestamp64Milli(now64(3))) as _version,
  toUInt8({{ is_deleted }}) as _is_deleted
{%- endmacro %}

{#
  Source d'un modèle gold "événement" incrémental :
    * nouvelles lignes silver (lot > watermark), hors patients opposés  -> _is_deleted = 0
    * en incrémental : lignes déjà publiées des patients devenus opposés -> _is_deleted = 1
  ReplacingMergeTree(_version, _is_deleted) + FINAL masque alors ces lignes : suppression logique
  propagée automatiquement à la release Postgres suivante.
#}
{% macro gold_event_source(silver_relation, wm) -%}
with opposes as (
    select person_id from {{ ref('slv_patient') }} where is_opposed
),
src as (
    select *, toUInt8(0) as del
    from {{ silver_relation }}
    where _batch_id > {{ wm }}
      and person_id not in (select person_id from opposes)
    {%- if is_incremental() %}
    union all
    select *, toUInt8(1) as del
    from {{ silver_relation }}
    where _batch_id <= {{ wm }}
      and person_id in (
          select h.person_id
          from {{ ref('slv_opposition') }} o
          inner join {{ ref('hub_person') }} h on h.source_key = o.pat_ipp
          where o._batch_id > {{ wm }}
      )
    {%- endif %}
)
{%- endmacro %}
