{{ config(severity = 'warn') }}

select s.*
from {{ ref('op_commercial_sales') }} s
left join {{ ref('dim_products') }} p on s.product_sku = p.product_sku
where p.product_sku is null
limit 5
