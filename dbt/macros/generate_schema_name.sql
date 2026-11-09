{# Utilise les noms de bases tels quels (bronze_ch, silver, gold_omop…) au lieu de lab_silver #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}{{ target.schema }}{%- else -%}{{ custom_schema_name | trim }}{%- endif -%}
{%- endmacro %}
