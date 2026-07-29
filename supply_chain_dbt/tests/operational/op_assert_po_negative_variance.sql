{{ config(severity = 'warn') }}

select * from {{ ref('op_inbound_supply') }}
where received_qty > (ordered_qty * 3)
limit 5
