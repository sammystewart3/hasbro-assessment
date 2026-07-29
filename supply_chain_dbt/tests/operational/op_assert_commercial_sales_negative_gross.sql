{{ config(severity = 'warn') }}

select * from {{ ref('op_commercial_sales') }}
where gross_amount < 0
limit 5
