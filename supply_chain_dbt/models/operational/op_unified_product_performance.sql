{{
    config(
        materialized='view',
        tags=['product', 'operational']
    )
}}

/*
    Model: op_unified_product_performance
    Description: Unified view connecting product dimensions, sales, inventory, 
                 shipments, and marketing data at the product SKU level.
    Grain: One row per product_sku.
*/

with products as (
    select * from {{ ref('dim_products') }}
),
sales as (
    select product_sku, sum(units) as total_units from {{ ref('op_commercial_sales') }} group by 1
),
inv as (
    select product_sku, sum(available_qty) as total_available from {{ ref('op_inventory_position') }} group by 1
),
ship as (
    select product_sku, sum(shipped_units) as total_shipped from {{ ref('op_shipment_fulfillment') }} group by 1
),
marketing as (
    select 
        c.product_sku,
        sum(p.spend) as total_marketing_spend,
        sum(p.clicks) as total_marketing_clicks,
        sum(p.conversions) as total_marketing_conversions
    from {{ ref('stg_marketing_campaigns') }} c
    left join {{ ref('op_marketing_performance') }} p on c.campaign_id = p.campaign_id
    group by 1
)

select 
    products.*,
    coalesce(sales.total_units, 0) as total_units_sold,
    coalesce(inv.total_available, 0) as total_inventory_available,
    coalesce(ship.total_shipped, 0) as total_units_shipped,
    coalesce(marketing.total_marketing_spend, 0) as total_marketing_spend,
    coalesce(marketing.total_marketing_clicks, 0) as total_marketing_clicks,
    coalesce(marketing.total_marketing_conversions, 0) as total_marketing_conversions
from products
left join sales on products.product_sku = sales.product_sku
left join inv on products.product_sku = inv.product_sku
left join ship on products.product_sku = ship.product_sku
left join marketing on products.product_sku = marketing.product_sku
