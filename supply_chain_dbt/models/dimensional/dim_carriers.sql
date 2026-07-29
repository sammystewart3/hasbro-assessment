{{
    config(
        materialized='view',
        tags=['dimension', 'carrier']
    )
}}

select 
    carrier_id,
    carrier_name,
    service_level,
    region,
    contracted_transit_days,
    active_flag
from {{ ref('stg_carrier_performance') }}
group by 1, 2, 3, 4, 5, 6
