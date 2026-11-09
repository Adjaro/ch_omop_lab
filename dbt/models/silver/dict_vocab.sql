-- Dictionnaire en mémoire : (vocabulaire, code source) -> concept_id.
-- Remplace des jointures répétées sur le référentiel par un lookup O(1) (dictGet).
{{ config(
    materialized='dictionary',
    fields=[
        ('source_vocab', 'String'),
        ('source_code', 'String'),
        ('target_concept_id', 'UInt32'),
        ('target_domain', 'String'),
        ('source_label', 'String')
    ],
    primary_key='source_vocab, source_code',
    layout='COMPLEX_KEY_HASHED()',
    lifetime='MIN 300 MAX 600'
) }}

select source_vocab, source_code, target_concept_id, target_domain, source_label
from {{ ref('slv_vocab_map') }}
