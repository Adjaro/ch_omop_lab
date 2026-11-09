-- Réplique incrémentale de bronze.pa_pas (Postgres) : seuls les lots _batch_id > watermark sont importés.
{{ config(order_by='(pas_ips)') }}

{{ replicate_from_pg('pa_pas') }}
