{{ config(severity = 'warn') }}

select * from {{ ref('stg_marketing_campaigns') }}
where campaign_start_date > campaign_end_date
--limit 5
