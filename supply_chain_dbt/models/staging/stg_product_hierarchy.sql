{{
    config(
        materialized='view',
        tags=['product', 'staging']
    )
}}

/*
    Model: stg_product_hierarchy
    Description: Standardizes product hierarchy metadata, cleans text formatting,
                 and deduplicates source records to keep only the latest effective
                 start date.
    Grain: One row per product_sku.
*/

-- models/staging/stg_product_hierarchy.sql
with raw_hierarchy as (

    select * from {{ source('main', 'product_hierarchy_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        -- standardize SKU using taxonomy lookup + one additional adhoc replacement 
        coalesce(tax_sku.standard_value,
            case 
                when substring(h.product_sku,1,4) = 'SKU-' then h.product_sku
                else replace(h.product_sku,'sku','SKU-')
                end) as product_sku,
        {{ clean_date('h.effective_start_date') }} as effective_start_date,
        {{ clean_date('h.effective_end_date') }} as effective_end_date,
        h.division,
        replace(h.brand_family_std, ' ', '') as brand_family,
        replace(h.franchise_std, ' ', '') as franchise,
        h.category_std as category,
        h.sub_category_std as sub_category,
        upper(h.status_std) as lifecycle_status,
        -- dedupe logic: rank by most recent effective_start_date per SKU
        row_number() over (
            partition by coalesce(tax_sku.standard_value, h.product_sku)
            order by h.effective_start_date desc
        ) as rn

    from raw_hierarchy as h

    left join taxonomy as tax_sku
        on h.product_sku = tax_sku.raw_value
        and tax_sku.mapping_type = 'sku_normalization'

),

deduped as (

    select n.*
    from normalized as n
    where n.rn = 1

)

select * from deduped