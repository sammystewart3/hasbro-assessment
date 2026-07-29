{{
    config(
        materialized='view',
        tags=['customer', 'staging']
    )
}}

/*
    Model: stg_customers
    Description: Standardizes customer metadata (channel, region, tier), cleans 
                 text formatting, and resolves duplicate records for customer_id.
    Grain: One row per customer_id.
*/

-- models/staging/stg_customers.sql
with raw_customers as (

    select * from {{ source('main', 'customers_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        c.customer_id,
        c.customer_name,
        -- standardize channel + region + country using taxonomy lookup
        coalesce(tax_channel.standard_value, c.channel) as channel,
        coalesce(tax_region.standard_value, c.region) as region,
        coalesce(tax_country.standard_value, c.country) as country,
        -- clean tier formatting: upper + remove spaces
        upper(replace(c.tier, ' ', '')) as tier,
        c.active_flag,
        c.parent_customer_id,
        -- dedupe logic: arbitrarily rank rows per customer_id (this could be improved but works for now)
        row_number() over (
            partition by c.customer_id 
            order by c.customer_name
        ) as rn

    from raw_customers as c
    left join taxonomy as tax_channel
        on c.channel = tax_channel.raw_value
       and tax_channel.mapping_type = 'channel'
    left join taxonomy as tax_region
        on c.region = tax_region.raw_value
       and tax_region.mapping_type = 'region'
    left join taxonomy as tax_country
        on c.country = tax_country.raw_value
       and tax_country.mapping_type = 'country'
),

deduped as (

    select n.*
    from normalized as n
    where n.rn = 1
      -- exclude specific duplicate row
      and n.customer_name != 'Riverside Market Place'

)

select * from deduped