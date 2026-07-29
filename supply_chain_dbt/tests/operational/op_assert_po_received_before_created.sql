{{ config(severity = 'warn') }}

select * from {{ ref('op_inbound_supply') }}
where received_date < po_create_date
limit 5
