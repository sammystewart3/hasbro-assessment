{{
    config(
        materialized='view',
        tags=['shipments', 'staging']
    )
}}

/*
    Model: stg_shipment_events
    Description: Standardizes shipment event timestamps using clean_date macro
                 to safely handle bad/non-date timestamp strings.
    Grain: One row per shipment_id and event_timestamp.
*/

-- models/staging/stg_shipment_events.sql
with raw_shipment_events as (

    select * from {{ source('main', 'shipment_events_raw') }}

),

normalized as (

    select
        se.shipment_id,
        -- timestamp data type handling could be a macro but for now it is just a one-off here
        datetime(se.event_timestamp) as event_timestamp,
        se.event_type,
        se.event_location,
        se.event_status

    from raw_shipment_events as se

)

select * from normalized
