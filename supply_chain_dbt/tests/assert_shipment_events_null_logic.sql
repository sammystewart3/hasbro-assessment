{{ config(severity = 'warn') }}

select * from {{ ref('stg_shipment_events') }}
where event_timestamp is null 
  and event_type in ('PICKED_UP', 'DELIVERED')
--limit 5
