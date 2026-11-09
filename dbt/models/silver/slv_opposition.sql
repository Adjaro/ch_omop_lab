-- Patients ayant exercé leur droit d'opposition (à exclure / supprimer logiquement du gold)
{{ config(order_by='pat_ipp') }}

select pat_ipp, min(date_opposition) as date_opposition, min(_batch_id) as _batch_id
from {{ ref('bz_pat_opposition') }}
group by pat_ipp
