{{
    config(
        materialized='view',
        tags=['fact', 'operational']
    )
}}

/*
    Model: op_inventory_position
    Description: Summarizes inventory position. Calculates weeks-of-supply 
                 by dividing available quantity by recent daily sales. Looks
                 at most recent 30 day period only.
    Grain: One row per snapshot_date, warehouse_id, and product_sku.
*/

with inv as (
    select * from {{ ref('stg_inventory_snapshots') }}
),

-- get anchor date from the sales fact
max_date_cte as (
    select max(transaction_date) as last_txn_date from {{ ref('op_commercial_sales') }}
),

sales as (
    select 
        s.product_sku,
        sum(s.units) as total_units_sold
    from {{ ref('op_commercial_sales') }} s, max_date_cte m
    where s.transaction_date >= date(m.last_txn_date, '-30 days')
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