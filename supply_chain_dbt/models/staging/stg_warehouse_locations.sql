{{
    config(
        materialized='view',
        tags=['warehouse', 'staging']
    )
}}

/*
    Model: stg_warehouse_locations
    Description: Standardizes warehouse locations, excludes invalid WH001 records,
                 and standardizes country using taxonomy lookup.
    Grain: One row per warehouse_id.
*/

-- models/staging/stg_warehouse_locations.sql
with raw_warehouses as (

    select * from {{ source('main', 'warehouse_locations_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        w.warehouse_id,
        w.warehouse_name,
        w.warehouse_type,
        w.region,
        coalesce(tax_country.standard_value, w.country) as country,
        w.timezone,
        w.active_flag

    from raw_warehouses as w
    left join taxonomy as tax_country
        on w.country = tax_country.raw_value
       and tax_country.mapping_type = 'country'
    -- exclude invalid warehouse_id WH001
    where w.warehouse_id != 'WH001'

)

select * from normalized
