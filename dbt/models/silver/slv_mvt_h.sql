-- Mouvements d'hébergement dédupliqués (règle CORA) :
-- pour un même (pas_ips, per_deb), on garde la per_fin la plus récente (NULL en dernier),
-- puis le lot le plus récent. LIMIT 1 BY remplace un ROW_NUMBER() + filtre.
{{ config(order_by='(pas_ips, per_deb)') }}

select
    pas_ips,
    pa_res_pat_per_deb as per_deb,
    pa_res_pat_per_fin as per_fin,
    ufo_ide,
    pa_res_pat_ide,
    _batch_id
from {{ ref('bz_pa_res_pat') }}
where pa_res_pat_typ = 'H'
order by pas_ips, per_deb, per_fin desc nulls last, _batch_id desc
limit 1 by pas_ips, per_deb
