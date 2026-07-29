{{
    config(
        materialized='view',
        tags=['pos', 'staging']
    )
}}

/*
    Model: stg_retail_pos
    Description: Standardizes retail POS metadata, cleans dates, handles missing
                 on-hand units, and deduplicates retailer/SKU combinations.
    Grain: One row per retailer_id, week_start_date, and product_sku.
*/

-- models/staging/stg_retail_pos.sql
with raw_retail_pos as (

    select * from {{ source('main', 'retail_pos_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        pos.retailer_id,
        {{ clean_date('pos.week_start_date') }} as week_start_date,
        -- standardize product SKU using taxonomy lookup
        coalesce(tax_sku.standard_value, pos.product_sku) as product_sku,
        cast(pos.store_count as numeric) as store_count,
        cast(pos.pos_units as numeric) as pos_units,
        cast(pos.pos_sales as numeric) as pos_sales,
        -- replace blank on_hand_units with 0
        cast(coalesce(nullif(pos.on_hand_units, ''), '0') as numeric) as on_hand_units,
        cast(pos.on_order_units as numeric) as on_order_units,
        upper(pos.currency) as currency,
        {{ clean_date('pos.feed_date') }} as feed_date,
        -- dedupe logic: rank by most recent week_start_date per retailer + SKU
        row_number() over (
            partition by pos.retailer_id, coalesce(tax_sku.standard_value, pos.product_sku), {{ clean_date('pos.week_start_date') }}
            order by {{ clean_date('pos.week_start_date') }} desc
        ) as rn

    from raw_retail_pos as pos
    left join taxonomy as tax_sku
        on pos.product_sku = tax_sku.raw_value
        and tax_sku.mapping_type = 'sku_normalization'

),

deduped as (

    select n.*
    from normalized as n
    where n.rn = 1

)

select * from deduped
