{{ config(severity = 'warn') }}

select * from {{ ref('stg_purchase_orders') }}
where received_date < po_create_date
--limit 5
