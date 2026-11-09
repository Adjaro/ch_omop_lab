-- Référentiel de mapping canonique (dernière version de chaque code)
{{ config(order_by='(source_vocab, source_code)') }}

select
    source_vocab,
    source_code,
    source_label,
    toUInt32(target_concept_id) as target_concept_id,
    target_domain,
    extra_num_3                 as range_low,
    extra_num_4                 as range_high,
    extra_txt                   as unit_or_route
from {{ ref('bz_ref_vocab_map') }}
order by source_vocab, source_code, _batch_id desc
limit 1 by source_vocab, source_code
