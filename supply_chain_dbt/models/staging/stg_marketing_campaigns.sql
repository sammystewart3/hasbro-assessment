{{
    config(
        materialized='view',
        tags=['marketing', 'staging']
    )
}}

/*
    Model: stg_marketing_campaigns
    Description: Standardizes marketing campaigns metadata, cleans platforms, SKUs,
                 regions, countries, budgets, and excludes invalid start dates.
    Grain: One row per campaign_id.
*/

-- models/staging/stg_marketing_campaigns.sql
with raw_campaigns as (

    select * from {{ source('main', 'marketing_campaigns_raw') }}

),

taxonomy as (

    select * from {{ ref('stg_taxonomy_lookup') }}

),

normalized as (

    select
        c.campaign_id,
        c.campaign_name,
        -- clean platform: remove spaces
        replace(c.platform, ' ', '') as platform,
        {{ clean_date('c.campaign_start_date') }} as campaign_start_date,
        {{ clean_date('c.campaign_end_date') }} as campaign_end_date,
        -- standardize product SKU and region using taxonomy lookup
        coalesce(tax_sku.standard_value, c.product_sku) as product_sku,
        -- conditional channel rule: if budget > 0 and channel is 'Social', replace with 'Paid Social'
        case
            when c.channel = 'Social' and cast(c.budget as numeric) > 0 then 'Paid Social'
            else c.channel
        end as channel,
        coalesce(tax_region.standard_value, c.region) as region,
        c.objective,
        -- handle non-numeric budget values
        cast(
            case 
                when c.budget GLOB '[0-9]*' then c.budget
                else '0'
            end as numeric
        ) as budget,
        upper(c.currency) as currency,
        replace(c.taxonomy_code,'-NAM','-NA') as taxonomy_code 

    from raw_campaigns as c
    left join taxonomy as tax_sku
        on c.product_sku = tax_sku.raw_value
       and tax_sku.mapping_type = 'sku_normalization'
    left join taxonomy as tax_region
        on c.region = tax_region.raw_value
       and tax_region.mapping_type = 'region'
    where c.campaign_start_date is not null 
      and c.campaign_start_date != ''

)

select * from normalized
