-- Réplique incrémentale de bronze.bio (Postgres) : seuls les lots _batch_id > watermark sont importés.
{{ config(order_by='(pas_ips, bio_id)') }}

{{ replicate_from_pg('bio') }}
