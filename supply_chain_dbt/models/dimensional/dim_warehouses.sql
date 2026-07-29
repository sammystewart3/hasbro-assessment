{{
    config(
        materialized='view',
        tags=['dimension', 'warehouse']
    )
}}

select * from {{ ref('stg_warehouse_locations') }}
