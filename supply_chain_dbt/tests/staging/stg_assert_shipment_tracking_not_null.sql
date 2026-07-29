{{ config(severity = 'warn') }}

select * from {{ ref('stg_shipments') }}
where tracking_number is null or tracking_number = ''
--limit 5
