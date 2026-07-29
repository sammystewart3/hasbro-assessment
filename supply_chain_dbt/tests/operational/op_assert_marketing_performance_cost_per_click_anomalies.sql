{{ config(severity = 'warn') }}

select * from {{ ref('op_marketing_performance') }}
where (spend > 0 and clicks = 0)
   or (spend = 0 and clicks > 0)
limit 5
