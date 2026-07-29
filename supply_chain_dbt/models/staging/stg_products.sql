-- models/staging/stg_products.sql
with raw_products as (

    select * from {{ source('main', 'products_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        p.source_system,
        -- fall back to raw_value if no taxonomy mapping exists
        coalesce(tax_sku.standard_value, p.product_sku) as product_sku,
        replace(p.alt_sku, '-', '') as alt_sku,
        p.product_name,
        replace(p.brand_family, ' ', '') as brand_family,
        replace(p.franchise, ' ', '') as franchise,
        replace(p.category, 'Play Sets', 'Playsets') as category,
        p.sub_category,
        replace(p.age_grade, 'Ages 4 and up', '4+') as age_grade,
        upper(p.lifecycle_status) as lifecycle_status,
        -- use clean_date macro for all date fields (across all models)
        {{ clean_date('p.launch_date') }} as launch_date,
        round(cast(replace(p.unit_cost,'unknown',0) as numeric), 2) as unit_cost,
        coalesce(tax_uom.standard_value, p.unit_of_measure) as unit_of_measure,
        p.updated_at,
        -- dedupe logic: rank by most recent updated_at per SKU
        row_number() over (partition by coalesce(tax_sku.standard_value, p.product_sku) order by date(p.updated_at) desc) as rn 
    from raw_products as p
    left join taxonomy as tax_sku
        on p.product_sku = tax_sku.raw_value
       and tax_sku.mapping_type = 'sku_normalization'
    left join taxonomy tax_uom
        on p.unit_of_measure = tax_uom.raw_value
       and tax_uom.mapping_type = 'uom'

),

deduped as (

    select n.* 
    from normalized as n
    where n.rn = 1
    
)

select * from deduped