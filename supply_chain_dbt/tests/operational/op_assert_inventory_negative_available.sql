{{ config(severity = 'warn') }}

select * from {{ ref('op_inventory_position') }}
where available_qty < 0
limit 5
