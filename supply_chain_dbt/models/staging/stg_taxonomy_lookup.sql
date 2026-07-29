-- models/staging/stg_taxonomy_lookup.sql
with source as (
    select * from {{ source('main', 'taxonomy_lookup_raw') }}
),

renamed as (
    select
        mapping_type,
        trim(raw_value) as raw_value,
        trim(standard_value) as standard_value,
        domain,
        active_flag,
        effective_start_date
    from source
    where active_flag = 'Y'
)

select * from renamed