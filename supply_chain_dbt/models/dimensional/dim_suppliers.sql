{{
    config(
        materialized='view',
        tags=['dimension', 'supplier']
    )
}}

select * from {{ ref('stg_suppliers') }}
