{{ config(severity = 'warn') }}

select * from {{ ref('op_inbound_supply') }}
where received_qty < ordered_qty 
    and lower(po_status) = 'closed'
limit 5
