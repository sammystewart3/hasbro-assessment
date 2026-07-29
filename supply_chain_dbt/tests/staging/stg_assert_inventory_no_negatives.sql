{{ config(severity = 'warn') }}

select * from {{ ref('stg_inventory_snapshots') }}
where on_hand_qty < 0 
   or allocated_qty < 0 
   or available_qty < 0
--limit 5
