-- Patient canonique : dernière version de chaque IPP (+ identifiant stable, + opposition)
{{ config(order_by='person_id') }}

with derniere_version as (
    select *
    from {{ ref('bz_pa_pat') }}
    order by pat_ipp, _batch_id desc
    limit 1 by pat_ipp
)
select
    h.person_id                             as person_id,
    p.pat_ipp                               as pat_ipp,
    p.sexe                                  as sexe,
    p.date_naiss                            as date_naiss,
    p.code_postal                           as code_postal,
    p.date_deces                            as date_deces,
    p.pat_ipp in (select pat_ipp from {{ ref('slv_opposition') }}) as is_opposed,
    p._batch_id                             as _batch_id
from derniere_version p
inner join {{ ref('hub_person') }} h on h.source_key = p.pat_ipp
