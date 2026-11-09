{# Unicité après FINAL (tables ReplacingMergeTree : les doublons de versions sont normaux avant fusion) #}
{% test unique_final(model, column_name) %}
select {{ column_name }}, count() as n
from {{ model }} final
where _is_deleted = 0
group by {{ column_name }}
having n > 1
{% endtest %}
