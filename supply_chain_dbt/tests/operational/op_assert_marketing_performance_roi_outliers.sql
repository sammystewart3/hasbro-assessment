{{ config(severity = 'warn') }}

select * from {{ ref('op_marketing_performance') }}
where (revenue / nullif(spend, 0)) > 50
limit 5
