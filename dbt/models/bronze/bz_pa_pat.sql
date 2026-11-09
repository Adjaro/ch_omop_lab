-- Réplique incrémentale de bronze.pa_pat (Postgres) : seuls les lots _batch_id > watermark sont importés.
{{ config(order_by='(pat_ipp, _batch_id)') }}

{{ replicate_from_pg('pa_pat') }}
