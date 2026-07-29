{{ config(severity = 'warn') }}

select u.*
from {{ ref('op_unified_product_performance') }} u
left join {{ ref('op_commercial_sales') }} s on u.product_sku = s.product_sku
left join {{ ref('op_inventory_position') }} i on u.product_sku = i.product_sku
where s.product_sku is null or i.product_sku is null
limit 5
