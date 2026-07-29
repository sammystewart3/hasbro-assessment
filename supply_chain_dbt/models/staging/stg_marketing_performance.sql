{{
    config(
        materialized='view',
        tags=['marketing', 'staging']
    )
}}

/*
    Model: stg_marketing_performance
    Description: Standardizes marketing performance daily metrics, cleans platforms,
                 and parses performance dates.
    Grain: One row per performance_date and campaign_id.
*/

-- models/staging/stg_marketing_performance.sql
with raw_performance as (

    select * from {{ source('main', 'marketing_performance_raw') }}

),

normalized as (

    select
        {{ clean_date('p.performance_date') }} as performance_date,
        p.campaign_id,
        -- clean platform: remove spaces
        replace(p.platform, ' ', '') as platform,
        cast(p.impressions as numeric) as impressions,
        cast(p.clicks as numeric) as clicks,
        -- handle blank video views
        cast(coalesce(nullif(p.video_views, ''), '0') as numeric) as video_views,
        cast(p.spend as numeric) as spend,
        cast(p.conversions as numeric) as conversions,
        cast(p.revenue as numeric) as revenue,
        upper(p.currency) as currency

    from raw_performance as p
    where p.performance_date is not null
      and p.performance_date != ''

)

select * from normalized
