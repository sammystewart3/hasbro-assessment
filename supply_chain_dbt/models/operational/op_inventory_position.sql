{{
    config(
        materialized='view',
        tags=['fact', 'operational']
    )
}}

/*
    Model: op_inventory_position
    Description: Summarizes inventory position. Calculates weeks-of-supply 
                 by dividing available quantity by recent daily sales.
    Grain: One row per snapshot_date, warehouse_id, and product_sku.
*/

with inv as (
    select * from {{ ref('stg_inventory_snapshots') }}
),

sales as (
    select 
        product_sku,
        sum(units) as total_units_sold
    from {{ ref('op_commercial_sales') }}
    where transaction_date >= date('now', '-30 days')
    group by 1
)

select 
    inv.*,
    coalesce(s.total_units_sold / 30.0, 0) as avg_daily_sales,
    case 
        when coalesce(s.total_units_sold / 30.0, 0) > 0 
        then (inv.available_qty / (s.total_units_sold / 30.0)) / 7.0
        else null 
    end as weeks_of_supply
from inv
left join sales s on inv.product_sku = s.product_sku
