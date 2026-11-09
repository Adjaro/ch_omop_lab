{# Chaque événement OMOP actif doit pointer vers une personne active #}
{% test no_orphan_person(model, column_name, person_model) %}
select e.{{ column_name }}
from (select {{ column_name }} from {{ model }} final where _is_deleted = 0) e
left anti join (select person_id from {{ person_model }} final where _is_deleted = 0) p
  on e.{{ column_name }} = p.person_id
{% endtest %}
