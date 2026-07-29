{{
    config(
        materialized='view',
        tags=['carrier', 'staging']
    )
}}

/*
    Model: stg_carrier_performance
    Description: Standardizes carrier performance records and resolves duplicate carrier_id
                 conflicts per audit notes.
    Grain: One row per carrier_id.
*/

-- models/staging/stg_carrier_performance.sql
with raw_carriers as (

    select * from {{ source('main', 'carrier_performance_raw') }}

),

normalized as (

    select
        cp.carrier_id,
        cp.carrier_name,
        cp.service_level,
        cp.region,
        cast(cp.contracted_transit_days as numeric) as contracted_transit_days,
        cp.active_flag

    from raw_carriers as cp
    -- README audit resolution: exclude 'Harbor Route Express / Express' for CAR-004, keeping 'HarborRoute Express / Air'
    where not (cp.carrier_id = 'CAR-004' and cp.carrier_name = 'Harbor Route Express' and service_level = 'Express')

)

select * from normalized
