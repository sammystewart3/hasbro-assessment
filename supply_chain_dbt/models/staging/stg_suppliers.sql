{{
    config(
        materialized='view',
        tags=['supplier', 'staging']
    )
}}

/*
    Model: stg_suppliers
    Description: Standardizes supplier records and resolves duplicate supplier_id
                 conflicts per audit notes.
    Grain: One row per supplier_id.
*/

-- models/staging/stg_suppliers.sql
with raw_suppliers as (

    select * from {{ source('main', 'suppliers_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        s.supplier_id,
        s.supplier_name,
        s.supplier_region,
        coalesce(tax_country.standard_value, s.country) as country,
        s.preferred_flag,
        cast(s.lead_time_days as numeric) as lead_time_days,
        s.active_flag

    from raw_suppliers as s
    left join taxonomy as tax_country
        on s.country = tax_country.raw_value
       and tax_country.mapping_type = 'country'
    -- exclude duplicate supplier_name 'Delta Plastic Works' for SUP-004
    where not (s.supplier_id = 'SUP-004' and s.supplier_name = 'Delta Plastic Works')

)

select * from normalized
