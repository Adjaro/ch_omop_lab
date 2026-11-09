-- Réplique incrémentale de bronze.actes (Postgres) : seuls les lots _batch_id > watermark sont importés.
{{ config(order_by='(pas_ips, acte_id)') }}

{{ replicate_from_pg('actes') }}
