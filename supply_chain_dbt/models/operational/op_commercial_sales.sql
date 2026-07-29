{{
    config(
        materialized='view',
        tags=['fact', 'operational']
    )
}}

/*
    Model: op_commercial_sales
    Description: Integrates sales orders and retail POS data into a unified 
                 commercial sales fact table.
    Grain: One row per order/POS transaction event.
*/

with sales as (
    select 
        order_id as transaction_id,
        'SALES_ORDER' as source_type,
        customer_id,
        product_sku,
        order_date as transaction_date,
        ordered_units as units,
        (ordered_units * unit_price) as gross_amount,
        currency
    from {{ ref('stg_sales_orders') }}
),

pos as (
    select 
        retailer_id as transaction_id,
        'POS' as source_type,
        retailer_id as customer_id,
        product_sku,
        week_start_date as transaction_date,
        pos_units as units,
        pos_sales as gross_amount,
        currency
    from {{ ref('stg_retail_pos') }}
)

select * from sales
union all
select * from pos
