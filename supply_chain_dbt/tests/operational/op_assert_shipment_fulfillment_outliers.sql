{{ config(severity = 'warn') }}

select * from {{ ref('op_shipment_fulfillment') }}
where fulfillment_duration_days > 30
limit 5
