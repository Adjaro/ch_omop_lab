-- Réplique incrémentale de bronze.pa_res_pat (Postgres) : seuls les lots _batch_id > watermark sont importés.
{{ config(order_by='(pas_ips, pa_res_pat_typ, pa_res_pat_ide)') }}

{{ replicate_from_pg('pa_res_pat') }}
