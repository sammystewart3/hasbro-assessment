{{ config(severity = 'warn') }}

select * from {{ ref('op_shipment_fulfillment') }}
where julianday(delivered_ts) < julianday(picked_up_ts)
limit 5
