{{
    config(
        materialized='view',
        tags=['dimension', 'customer']
    )
}}

select * from {{ ref('stg_customers') }}
