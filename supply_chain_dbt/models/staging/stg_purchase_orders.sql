{{
    config(
        materialized='view',
        tags=['purchase_orders', 'staging']
    )
}}

/*
    Model: stg_purchase_orders
    Description: Standardizes purchase orders metadata, SKUs, warehouses, statuses,
                 and deduplicates records.
    Grain: One row per po_id and po_line_id.
*/

-- models/staging/stg_purchase_orders.sql
with raw_purchase_orders as (

    select * from {{ source('main', 'purchase_orders_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        po.po_id,
        po.po_line_id,
        po.supplier_id,
        coalesce(tax_sku.standard_value, po.product_sku) as product_sku,
        coalesce(tax_wh.standard_value, po.warehouse_id) as warehouse_id,
        {{ clean_date('po.po_create_date') }} as po_create_date,
        {{ clean_date('po.requested_delivery_date') }} as requested_delivery_date,
        {{ clean_date('po.received_date') }} as received_date,
        coalesce(tax_status.standard_value, upper(po.po_status)) as po_status,
        cast(po.ordered_qty as numeric) as ordered_qty,
        cast(po.received_qty as numeric) as received_qty,
        cast(po.unit_cost as numeric) as unit_cost,
        upper(po.currency) as currency,
        -- Deduplication logic: rank by most recent create date per PO / line
        row_number() over (
            partition by po.po_id, po.po_line_id
            order by po.po_create_date desc
        ) as rn

    from raw_purchase_orders as po
    left join taxonomy as tax_sku
        on po.product_sku = tax_sku.raw_value
       and tax_sku.mapping_type = 'sku_normalization'
    left join taxonomy as tax_wh
        on po.warehouse_id = tax_wh.raw_value
       and tax_wh.mapping_type = 'warehouse_normalization'
    left join taxonomy as tax_status
        on lower(po.po_status) = lower(tax_status.raw_value)
       and tax_status.mapping_type = 'status'
       and tax_status.domain = 'supply_chain'

),

deduped as (

    select n.*
    from normalized as n
    where n.rn = 1

)

select * from deduped
