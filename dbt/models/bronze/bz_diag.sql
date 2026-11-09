-- Réplique incrémentale de bronze.diag (Postgres) : seuls les lots _batch_id > watermark sont importés.
{{ config(order_by='(pas_ips, diag_id)') }}

{{ replicate_from_pg('diag') }}
