{{
    config(
        materialized='view',
        tags=['fact', 'operational']
    )
}}

/*
    Model: op_inbound_supply
    Description: Consolidates purchase order data to track inbound supply 
                 fulfillment metrics.
    Grain: One row per po_id and po_line_id.
*/

select 
    *,
    (received_qty - ordered_qty) as qty_variance,
    (julianday(received_date) - julianday(requested_delivery_date)) as delivery_lag_days
from {{ ref('stg_purchase_orders') }}
