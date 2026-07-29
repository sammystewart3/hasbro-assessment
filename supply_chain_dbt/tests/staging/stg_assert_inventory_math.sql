{{ config(severity = 'warn') }}

select * from {{ ref('stg_inventory_snapshots') }}
where (on_hand_qty - allocated_qty) != available_qty
--limit 5
