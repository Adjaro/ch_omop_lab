-- Réplique incrémentale de bronze.pharma (Postgres) : seuls les lots _batch_id > watermark sont importés.
{{ config(order_by='(pas_ips, presc_id)') }}

{{ replicate_from_pg('pharma') }}
