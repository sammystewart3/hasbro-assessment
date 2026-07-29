{{ config(severity = 'warn') }}

select * from {{ ref('stg_retail_pos') }}
where pos_units < 0 or pos_sales < 0
--limit 5
