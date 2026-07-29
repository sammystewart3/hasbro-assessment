{{
    config(
        materialized='view',
        tags=['shipments', 'staging']
    )
}}

/*
    Model: stg_shipments
    Description: Standardizes shipments metadata, SKUs, warehouses, shipment status,
                 and deduplicates shipment records.
    Grain: One row per shipment_id.
*/

-- models/staging/stg_shipments.sql
with raw_shipments as (

    select * from {{ source('main', 'shipments_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        sh.shipment_id,
        sh.order_id,
        sh.customer_id,
        coalesce(tax_sku.standard_value, sh.product_sku) as product_sku,
        coalesce(tax_wh.standard_value, sh.warehouse_id) as warehouse_id,
        sh.carrier_id,
        {{ clean_date('sh.ship_date') }} as ship_date,
        {{ clean_date('sh.delivery_date') }} as delivery_date,
        -- standardize shipment status ('delivered' -> 'Delivered')
        case 
            when lower(sh.shipment_status) = 'delivered' then 'Delivered'
            else sh.shipment_status
        end as shipment_status,
        cast(sh.shipped_units as numeric) as shipped_units,
        cast(sh.freight_cost as numeric) as freight_cost,
        upper(sh.currency) as currency,
        sh.tracking_number,
        -- dedupe logic: rank by most recent ship_date per shipment_id
        row_number() over (
            partition by sh.shipment_id
            order by sh.ship_date desc
        ) as rn

    from raw_shipments as sh
    left join taxonomy as tax_sku
        on sh.product_sku = tax_sku.raw_value
       and tax_sku.mapping_type = 'sku_normalization'
    left join taxonomy as tax_wh
        on sh.warehouse_id = tax_wh.raw_value
       and tax_wh.mapping_type = 'warehouse_normalization'

),

deduped as (

    select n.*
    from normalized as n
    where n.rn = 1

)

select * from deduped
