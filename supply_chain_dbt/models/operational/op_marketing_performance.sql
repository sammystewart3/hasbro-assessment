{{
    config(
        materialized='view',
        tags=['marketing', 'operational']
    )
}}

/*
    Model: op_marketing_performance
    Description: Joins campaign metadata with daily performance metrics 
                 for comprehensive marketing analysis.
    Grain: One row per campaign_id and performance_date.
*/

select 
    perf.*,
    camp.campaign_name,
    camp.product_sku,
    camp.channel,
    camp.region,
    --perf.country,
    camp.objective,
    camp.budget
from {{ ref('stg_marketing_performance') }} perf
left join {{ ref('stg_marketing_campaigns') }} camp on perf.campaign_id = camp.campaign_id
