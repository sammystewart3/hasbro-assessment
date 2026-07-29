{{
    config(
        materialized='view',
        tags=['sales', 'staging']
    )
}}

/*
    Model: stg_sales_orders
    Description: Standardizes sales orders metadata (SKUs, dates, status, currency),
                 handles non-numeric ordered units, and deduplicates records.
    Grain: One row per order_id and order_line_id.
*/

-- models/staging/stg_sales_orders.sql
with raw_sales_orders as (

    select * from {{ source('main', 'sales_orders_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        s.order_id,
        s.order_line_id,
        s.customer_id,
        -- standardize product SKU using taxonomy lookup
        coalesce(tax_sku.standard_value, s.product_sku) as product_sku,
        {{ clean_date('s.order_date') }} as order_date,
        {{ clean_date('s.requested_ship_date') }} as requested_ship_date,
        {{ clean_date('s.ship_date') }} as ship_date,
        upper(s.order_status) as order_status,
        -- if ordered_units is non-numeric, fallback to shipped_units
        cast(
            case 
                when s.ordered_units GLOB '[0-9]*' then s.ordered_units
                else s.shipped_units
            end as numeric
        ) as ordered_units,
        cast(s.shipped_units as numeric) as shipped_units,
        cast(s.unit_price as numeric) as unit_price,
        upper(s.currency) as currency,
        s.cancel_reason,
        -- dedupe logic: rank by most recent order_date per order_id / line_id
        row_number() over (
            partition by s.order_id, s.order_line_id 
            order by s.order_date desc
        ) as rn

    from raw_sales_orders as s
    left join taxonomy as tax_sku
        on s.product_sku = tax_sku.raw_value
       and tax_sku.mapping_type = 'sku_normalization'

),

deduped as (

    select n.*
    from normalized as n
    where n.rn = 1

)

select * from deduped
