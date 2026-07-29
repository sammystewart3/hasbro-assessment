{{ config(severity = 'warn') }}

select * from {{ ref('stg_sales_orders') }}
where julianday(ship_date) - julianday(requested_ship_date) >= 7
--limit 5
