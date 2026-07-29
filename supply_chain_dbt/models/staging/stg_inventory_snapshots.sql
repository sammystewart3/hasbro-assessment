{{
    config(
        materialized='view',
        tags=['inventory', 'staging']
    )
}}

/*
    Model: stg_inventory_snapshots
    Description: Standardizes inventory snapshot dates, warehouse IDs, SKUs,
                 UoMs, inventory status, replaces blank quantities with 0,
                 and deduplicates identical snapshot rows.
    Grain: One row per snapshot_date, warehouse_id, and product_sku.
*/

-- models/staging/stg_inventory_snapshots.sql
with raw_inventory as (

    select * from {{ source('main', 'inventory_snapshots_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        {{ clean_date('i.snapshot_date') }} as snapshot_date,
        -- standardize warehouse ID and product SKU using taxonomy lookup
        coalesce(tax_wh.standard_value, i.warehouse_id) as warehouse_id,
        coalesce(tax_sku.standard_value, i.product_sku) as product_sku,
        -- replace blank quantities with 0
        cast(coalesce(nullif(i.on_hand_qty, ''), '0') as numeric) as on_hand_qty,
        cast(coalesce(nullif(i.allocated_qty, ''), '0') as numeric) as allocated_qty,
        cast(coalesce(nullif(i.available_qty, ''), '0') as numeric) as available_qty,
        cast(coalesce(nullif(i.in_transit_qty, ''), '0') as numeric) as in_transit_qty,
        cast(coalesce(nullif(i.safety_stock_qty, ''), '0') as numeric) as safety_stock_qty,
        coalesce(tax_uom.standard_value, i.unit_of_measure) as unit_of_measure,
        -- standardize inventory status casing ('available' -> 'Available')
        case 
            when lower(i.inventory_status) = 'available' then 'Available'
            else i.inventory_status
        end as inventory_status,
        -- dedupe: rank identical rows to keep distinct records
        row_number() over (
            partition by i.snapshot_date, i.warehouse_id, i.product_sku
            order by i.snapshot_date
        ) as rn

    from raw_inventory as i
    left join taxonomy as tax_wh
        on i.warehouse_id = tax_wh.raw_value
       and tax_wh.mapping_type = 'warehouse_normalization'
    left join taxonomy as tax_sku
        on i.product_sku = tax_sku.raw_value
       and tax_sku.mapping_type = 'sku_normalization'
    left join taxonomy as tax_uom
        on i.unit_of_measure = tax_uom.raw_value
       and tax_uom.mapping_type = 'uom'

),

deduped as (

    select n.*
    from normalized as n
    where n.rn = 1

)

select * from deduped
