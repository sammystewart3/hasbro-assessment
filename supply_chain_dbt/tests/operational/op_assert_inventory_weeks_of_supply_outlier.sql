{{ config(severity = 'warn') }}

select * from {{ ref('op_inventory_position') }}
where weeks_of_supply > 730
or weeks_of_supply < -365
limit 5
