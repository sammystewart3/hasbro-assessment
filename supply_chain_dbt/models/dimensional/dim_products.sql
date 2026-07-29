{{
    config(
        materialized='view',
        tags=['dimension', 'product']
    )
}}

select
    p.product_sku,
    p.product_name,
    p.brand_family,
    p.franchise,
    p.category,
    p.sub_category,
    p.age_grade,
    h.division,
    p.lifecycle_status,
    p.unit_cost
from {{ ref('stg_products') }} p
left join {{ ref('stg_product_hierarchy') }} h 
    on p.product_sku = h.product_sku
