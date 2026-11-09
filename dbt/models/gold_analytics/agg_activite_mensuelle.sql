-- Activité mensuelle par type de séjour et UF (pour Grafana / exploration)
{{ config(order_by='(mois, type_sejour, care_site_id)') }}

select
    toStartOfMonth(visit_start_date)                              as mois,
    assumeNotNull(visit_source_value)                             as type_sejour,
    coalesce(care_site_id, 0)                                     as care_site_id,
    count()                                                       as nb_sejours,
    uniqExact(person_id)                                          as nb_patients,
    round(avg(dateDiff('day', visit_start_date, visit_end_date)), 2) as duree_moyenne_jours
from {{ ref('visit_occurrence') }} final
where _is_deleted = 0
group by mois, type_sejour, care_site_id
