{{ config(severity = 'warn') }}

with joined as (
    select 
        shipment_id,
        max(case when event_type = 'PICKED_UP' then event_timestamp end) as picked_up_ts,
        max(case when event_type = 'DELIVERED' then event_timestamp end) as delivered_ts
    from {{ ref('stg_shipment_events') }}
    group by 1
)
select * from joined
where picked_up_ts >= delivered_ts
--limit 5
