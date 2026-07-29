{{
    config(

        materialized='view',
        tags=['dimension', 'date']
        
    )
}}

with date_range as (

    select min(date(order_date)) as min_date, max(date(order_date)) as max_date 
    from {{ ref('stg_sales_orders') }}
    union all
    select min(date(week_start_date)), max(date(week_start_date)) 
    from {{ ref('stg_retail_pos') }}

),

bounds as (

    select min(min_date) as start_date, max(max_date) as end_date from date_range

),

recursive_dates as (

    select start_date as date_value from bounds
    union all
    select date(date_value, '+1 day')
    from recursive_dates
    where date_value < (select end_date from bounds)

)

select 
    date_value as date_key,
    strftime('%Y-%m-%d', date_value) as full_date,
    strftime('%Y', date_value) as year,
    strftime('%m', date_value) as month,
    strftime('%W', date_value) as week_of_year,
    strftime('%w', date_value) as day_of_week
from recursive_dates
