-- Séjour canonique : identifiants stables + UF médicale + UF d'hébergement dédupliquée
{{ config(order_by='visit_occurrence_id') }}

with pas as (
    select * from {{ ref('bz_pa_pas') }}
    order by pas_ips, _batch_id desc
    limit 1 by pas_ips
),
uf_med as (
    select pas_ips, argMax(ufo_ide, (pa_res_pat_per_deb, _batch_id)) as uf_med
    from {{ ref('bz_pa_res_pat') }}
    where pa_res_pat_typ = 'M'
    group by pas_ips
),
uf_heb as (
    select pas_ips, argMin(ufo_ide, per_deb) as uf_heb
    from {{ ref('slv_mvt_h') }}
    group by pas_ips
)
select
    hv.visit_occurrence_id                  as visit_occurrence_id,
    hp.person_id                            as person_id,
    p.pas_ips                               as pas_ips,
    p.iep_ide                               as iep_ide,
    p.pat_ipp                               as pat_ipp,
    p.type_sejour                           as type_sejour,
    p.pas_per_deb                           as start_dt,
    p.pas_per_fin                           as end_dt,
    p.mode_entree                           as mode_entree,
    p.mode_sortie                           as mode_sortie,
    nullIf(m.uf_med, 0)                     as uf_med,
    nullIf(h.uf_heb, 0)                     as uf_heb,
    m.uf_med != h.uf_heb and h.uf_heb != 0  as uf_divergente,
    p._batch_id                             as _batch_id
from pas p
inner join {{ ref('hub_visit') }}  hv on hv.source_key = p.iep_ide
inner join {{ ref('hub_person') }} hp on hp.source_key = p.pat_ipp
left join uf_med m on m.pas_ips = p.pas_ips
left join uf_heb h on h.pas_ips = p.pas_ips
