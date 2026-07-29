{{ config(severity = 'warn') }}

select * from {{ ref('stg_marketing_performance') }}
where not (impressions > clicks and clicks > conversions)
   or not (impressions > video_views)
--limit 5
