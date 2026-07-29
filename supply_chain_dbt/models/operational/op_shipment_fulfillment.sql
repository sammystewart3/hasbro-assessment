{{
    config(
        materialized='view',
        tags=['fact', 'operational']
    )
}}

/*
    Model: op_shipment_fulfillment
    Description: Integrates shipment and event data to calculate fulfillment 
                 performance (e.g., pick-to-deliver duration).
    Grain: One row per shipment_id.
*/

with shipments as (
    select * from {{ ref('stg_shipments') }}
),

events as (
    select 
        shipment_id,
        min(case when event_type = 'PICKED_UP' then event_timestamp end) as picked_up_ts,
        max(case when event_type = 'DELIVERED' then event_timestamp end) as delivered_ts
    from {{ ref('stg_shipment_events') }}
    group by 1
)

select 
    sh.*,
    ev.picked_up_ts,
    ev.delivered_ts,
    (julianday(ev.delivered_ts) - julianday(ev.picked_up_ts)) as fulfillment_duration_days
from shipments sh
left join events ev on sh.shipment_id = ev.shipment_id
