-- La dédup H doit laisser au plus une ligne par (pas_ips, per_deb)
select pas_ips, per_deb, count() as n
from {{ ref('slv_mvt_h') }}
group by pas_ips, per_deb
having n > 1
