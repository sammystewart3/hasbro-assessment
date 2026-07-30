Sammy Stewart
July 28, 2026

Hasbro - Senior Analytics Engineer Take-Home Assessment


### Project Structure Overview

Models: built in three phases.
- First, the staging models (prefixed with stg_), which do basic cleanup & transormation of the _raw data tables.
    - I've used the taxonomy_lookup table where possible as a means of normalizing the dimensional data.
    - I've then layered on some additional ad hoc normalization steps to fill in some of the remaining gaps (including additional renaming/reclassification, data type formatting, string trimming/cleaning, basic de-duplication). 
    - Specifics on all the additional assumptions/normalization steps I took for each staging model can be found in the `Data Quality Audit for Staging Models` section at the end of this README. 
- Second, the dimensional models (prefixed with dim_), which are built from the staging models and are very similar to staging models in many respects -- the slight difference being the dim models are distilled down to truly unique rows per dimensional grain, and they also handle certain dimensional joins (such as joining products with product_hierarchy tables) to get a final, fully synthesized product-level dimension.
    - See `Operational Models` section near the end of this README for more detail about each op model I've created.
- Third, the operational models (prefixed with op_), which are built from the staging models + the dimensional models. The operational models handle the more complex transformation/synthesis/joining required for final consumption & analysis. 

Tests: built in two phases, to align with the staging and operational model phases.
- For failed tests, for the time being I have set the default severity level to 'warn'...this is because I am still getting acclimated with the context surrounding teh data; ultimately I would want to level up the severity to 'fail' once these models were deployed to production...but first I need to understand WHY the ones that are failing are failing.
- For now, depending on the specifics of the failure, failed tests will either require more troubleshooting on the back-end, OR would require further exploration across the company more broadly (i.e. checking w/ stakeholders abt what the flags actually mean and how to handle them moving forward).

More detail on the specific tests can be found in the below `Tests` section. Follow-up questions for stakeholders stemming from these test outcomes can be found in the `Initital Questions` section. A summary of some of my initial takeaways, after looking at the synthesized data, can be found in the `Topline Takeaways` section.

Notes on things I have NOT done in my project setup here (but would like to do in an ideal world): 
- No CI/CD prod vs dev considerations - SQLite didn't immediately lend itself to this sort of set up.
- Preferably I would partition the various models inside medallion architecture (i.e. staging models would be in bronze, maybe a silver layer with dimensional / op models, and final consumption-ready marts in gold), but I haven't done that here either, for similar SQLite related reasons (couldnt immediately figure out how to create diff db schema)...so instead I've just used consistent prefixes when naming models to identify what category they fall into (stg_ or op_).
- Not worrying about linting / SQLFluff stuff for now, either.
- I would like to create some more dbt macros, to handle some of the additional normalization/classification steps (at certain points I felt like my code was starting to get a bit verbose, model to model...)
- Didn't have time to ensure fully-consistent decimal place conventions across all numeric fields.
- There is a duplicate marketing cmapaign row in the marketing data that I didn't catch until just now. "CMP-001" campaign id is associated with both FaceSpace and Facebook. Initially I thought the same campaign could be run across different platforms, but I can see now the data is literally duplicated across the two platform rows, meaning that the Facebook one (I presume) should not be included here.



### Tests

General testing approach: I used a mix of simple yml tests and more complex tests stored as custom sql in the tests folder. Both sets of tests are evaluated on `dbt build`.

Staging models - simple tests:
- Primary keys: Verified unique and non-null values for primary identifiers (product_sku, customer_id, campaign_id, shipment_id, etc.) across all core models.
- Composite grain integrity: used compound key tests (e.g., retailer_id + week_start_date + product_sku and campaign_id + performance_date + platform) to ensure unique data granularity where primary keys are composite.
- Required fields: enforced non-null constraints on mandatory date and dimension fields to guarantee data completeness for downstream modeling.
- Severity strategy: all data quality tests are configured with a warn severity to support ongoing data discovery, with plans to elevate to fail for production-level rigor in the future.

Staging models - complex tests:
- Sales orders - check the time btwn requested ship date and actual ship date - if there are big lag times btwn requested and actual, i.e. greater than or equal to 7 days (1 week)? Flag if true.
    - And are there purchase orders where received_date < created_date? Flag if so.
- Retail POS - what do negative pos_units / pos_sales values represent? are these returns/refunds or something? how to handle in final marts - exclude or include? Flag if negative values are present.
- Marketing campaigns - campaign start date < campaign end date. Flag if false.
- Marketing performance - the following two conditions should always be true: 
    - impressions > clicks > conversions 
    - impressions > video views 
    - Flag if either condition returns false.
- Inventory - any negative values in any fields? Flag if true.
- Inventory - does [on_hand_qty - allocated_qty = available_qty]? Flag if false.
- Shipments - do any shipments have blank tracking numbers? Flag if true.
- Shipment events - do picked_up and delivered timestamps make sequential sense for each shipment (i.e. the following condition should be true: date picked_up < date delivered)? Flag if false.
- Shipment events - evaluate this condition: event_timestamp is null and event_type in (PICKED_UP,DELIVERED). Flag if true.


Operational models - simple tests:
- Primary key integrity: enforced unique and not_null constraints on the primary identifiers of all dimension tables (e.g., product_sku, customer_id) to ensure a distinct, reliable grain.
- Operational key tracking: applied unique and not_null constraints to core operational identifiers (like shipment_id and product_sku in the unified mart) to guarantee record-level consistency in final reporting.
- Completeness checks: added not_null tests to mandatory fields across both dimension and fact layers to ensure essential data points (like dates and IDs) are always populated.
- Standardized alerting: configured all tests with severity: warn to ensure data quality issues are surfaced for review without blocking production pipeline execution.

Operational models - complex tests:
- Commercial sales integrity: monitors for non-sensical negative gross sales and validates referential integrity by flagging products in sales data that are missing from the master product dimension.
- Inventory health: checks for negative available inventory balances and identifies "weeks-of-supply" outliers that indicate potential data entry errors or extreme stock anomalies.
- Logistics performance: validates temporal consistency in shipment fulfillment by flagging records where delivery occurred before pickup and identifying shipments with unrealistically long fulfillment durations.
- Inbound supply accuracy: ensures purchase order lifecycle validity by flagging receipts dated before order creation and highlighting significant quantity variances between ordered and received stock.
- Marketing efficiency: monitors for performance anomalies, such as spend occurring without clicks or unrealistic ROI thresholds, to maintain data quality in marketing investment analysis.
- Cross-domain consistency: validates data parity in the unified product performance mart, ensuring total product records are correctly accounted for across both commercial sales and inventory fact sets.


### Initial Questions

Initial questions (stemming from any final tests that failed - ideally all these questions will be resolved before any final analysis is presented). 

Staging Data Questions
- `stg_inventory_snapshots` (inventory math): for WH-004/SKU-1004, our calculated inventory math (on_hand - allocated != available) doesn't balance (0 - 50 != 0). Should we re-verify how available_qty is calculated at the source?
- `stg_inventory_snapshots` (negative snapshot): We have records showing negative inventory (on_hand_qty of -25) for WH-001/SKU-1005. Should inventory snapshots ever contain negative quantities?
- `stg_marketing_performance` (engagement anomalies): Campaign CMP-001 shows -10 clicks despite having significant impressions and spend. How should we handle unrealistic values in marketing engagement metrics?
- `stg_retail_pos` (negative POS): POS data for customer CUST-003 shows negative units (-5) and a negative gross amount of -99.95. Are these standard returns, or should we filter these out of our sales reporting?
- `stg_purchase_orders` (PO timing): Purchase order PO-5003 for supplier SUP-003 was received on 2024-01-29, which is before the PO was created (2024-02-01). Should we investigate this receipt entry?
- `stg_shipment_events` (sequencing): Shipment SHP-9003 shows a delivery timestamp (2024-02-28 08:00) that is earlier than the pickup timestamp (2024-02-28 12:00). Could this be a timezone or manual entry error?
- `stg_shipments` (missing tracking): Shipment SHP-9005 is marked as 'Delivered' but has no tracking number provided. Is this expected for certain shipment types, or is the tracking number missing from the source?

Operational Data Questions
- `op_commercial_sales` (Orphaned Products): Sales are being recorded for SKU SKU-8888 (order SO-10008), but this product does not exist in our master product dimension. Can you confirm if this is a valid SKU that needs to be added?
- `op_unified_product_performance` (Cross-Domain Orphans): SKU SKU-9999 appears in the unified product mart but is missing from core commercial sales and inventory facts. Could you clarify the status of this "Legacy Item"?


### Topline Takeaways

Data Quality Observations (The Issues)
- Systemic tracking gaps: discrepancies in shipment sequencing and missing tracking numbers suggest gaps in carrier data ingestion, while inbound PO records show receipt dates preceding creation, indicating workflow synchronization issues.
- Inventory accuracy: recurring inventory math imbalances (on-hand - allocated != available) and negative quantity reporting suggest a need to tighten the sync between physical stock counts and ERP systems.
- Marketing attribution: significant spending without corresponding engagement activity, combined with orphan product SKUs across domains, highlights critical vulnerabilities in our tracking and master data management processes.

Business Performance Highlights (The Results)
- High-performing product: SKU-1002 is our top performer with 330 units sold; despite only $1,800 in marketing spend, it has maintained strong conversion volume, making it our most efficient product by unit-to-spend ratio.
- Marketing ROI leaders: the GG_Sprout_Awareness_Q1 campaign is driving the highest impact, generating 230 conversions on a $7,300 spend, significantly outperforming RoboRiver_Performance which yielded only 140 conversions on $3,200.
- Sales vs spend disconnect: SKU-1001 has the highest marketing investment ($7,300), yet ranks only 3rd in unit sales (265 units), suggesting this product may be reaching a point of diminishing returns or requires a content refresh.



------------------------------------------------------------------
------------------------------------------------------------------


### Operational Models

`op_commercial_sales`
- UNIONS sales_orders and retail_pos into a single, analysis-ready fact table.
    - Double-check this methodology is appropriate - is there a chance that sales orders and retail POS data is duplicative?
- Tracks transaction volume and revenue across two key commercial sources.

`op_inventory_position`
- Monitors daily stock levels by warehouse.
- Calculates "Weeks of Supply" using a 30-day rolling sales average to flag over/under-stock risks.
- NOTE: looks at most recent 30 day period only, using max(transaction_date) as anchor date.

`op_shipment_fulfillment`
- Joins shipment headers with lifecycle events (picked, delivered).
- Computes fulfillment speed (pick-to-delivery duration) per shipment.

`op_inbound_supply`
- Tracks inbound PO fulfillment.
- Quantifies delivery lag (days from request) and inventory volume variance.

`op_marketing_performance`
- Bridges campaign metadata with daily engagement and conversion metrics.
- Centralizes ROI analysis across platforms and regional campaigns.

`op_unified_product_performance`
- The "Master Mart": SKU-level view connecting sales, inventory availability, marketing performance, and shipping output.
- Provides a consolidated dashboard for overall product health.
- NOTE: marketing/shipping/sales dimensions that are more granular than SKU are NOT included here - measurements are aggregated by SKU.


### Data Quality Audit for Staging Models

Here are some specific notes & assumptions about data quality issues that I found in the various raw data tables All of the logic & assumptions articulated below feed directly into the staging models themselves & effectively serve as the basis for the staging models. Fields are only mentioned below if they appeared problematic to me in some fashion (fields that looked good aren't mentioned and are just pulled through to the staging models verbatim). 

`products_raw` & `product_hierarchy_raw` 
- formatting/classification issues:
    - `product_sku` - inconsistent formatting (casing, dash vs no dash)
        - resolution: taxonomy_lookup
    - `alt_sku` - inconsistent formatting AND sometimes blank
        - resolution: taxonomy_lookup
    - `brand_family` & `franchise` - inconsistent classification (i.e. SproutWorks vs Sprout Works, Orbit Ocean vs OceanOrbit)
        - NOTE: don't need to worry about Orbit Ocean vs OceanOrbit as this is the result of duplicate SKUs - this will be handled in de-dupe logic outlined in section below
        - resolution: trim() + replace " " with ""
    - `category` - inconsistent spacing AND casing (i.e. Playsets vs Play Sets)
        - resolution: minimal change for now, just replace "Play Sets" with "Playsets"
    - `age_grade` - inconsistent formatting (i.e. 4+ vs "Ages 4 and up")
        - resolution: keep it literal/narrow for now, just replace "Ages 4 and up" with "4+"
    - `lifecycle_status` - inconsistent casing 
        - resolution: upper()
    - `launch_date` - inconsistent date formatting AND blank in cases where `lifecycle_status` = "Inactive"
        - resolution: macro: clean_date() 
    - `unit_cost` - mix of datatypes (i.e. 12.5 vs "unknown") AND inconsistent decimal places
        - resolution: replace "unknown" with "0" + cast as numeric decimal(2)
    - `unit_of_measure` - inconsistent classification (EA vs each)
        - resolution: taxonomy_lookup
- duplications & conflicts:
    - duplicate `product_sku` values in `products_raw` across multiple systems (i.e SKU-1001 is both PLM and ERP, SKU-1007 has category and subcategory flipped around both ways)
        - resolution: use most recent updated_at entry as row of record, as presumably this is the most up-to-date information for said product - this will resolve both duplicate issues flagged here
    - duplicate `product_sku` values in `product_hierarchy_raw` - diff start dates, one row has end date
        - resolution: use most recent `effective_start_date` - presumably this is the best info for that product (this is also the row with no end date provided, so this tracks)

`customers_raw` 
- formatting/classification issues: 
    - `customer_name` - there's a dupe customer ID row with two diff names, otherwise this field is fine
        - resolution: this will be handled by de-dupe logic below
    - `channel` - inconsistent classification (i.e. Mass vs Mass Retail, Online vs Ecom)
        - resolution: taxonomy_lookup
    - `region` - inconsistent classification (i.e. North America vs NA)
        - resolution: taxonomy_lookup
    - `tier` - inconsistent formatting
        - resolution: upper() + replace(" ","-") with ""
- duplications & conflicts: 
    - duplicate customer_id CUST-006
        - resolution: no functional difference as far as i can tell between two dupe rows, and there is no date-related field to use as a tie-breaker; as such, somewhat arbitrarily, i take the row where customer_name is "Riverside Marketplace" (so model exclusion logic will just be `customer_name` != "Riverside Market Place")

`sales_orders_raw` 
-  formatting/classification issues: 
    - `order_id` - contains duplicate values
        - resolution: this will be handled by de-dupe logic below
    - `product_sku` - inconsistent formatting
        - macro: clean_product_sku()
    - `order_status` - inconsistent casing
        - resolution: upper()
    - `ordered_units` - non-numeric values included (i.e. abc) 
        - resolution: if `order_units` is non-numeric take `shipped_units` value instead
    - `currency` - inconsistent casing
        - resolution: upper()
- duplications & conflicts: 
    - dupe order_ids
        - resolution: take row with most recent order date

`retail_pos_raw` 
- formatting/classification issues: 
    - `week_start_date` - date formatting inconsistent
        - macro: clean_date()
    - `product_sku` - inconsistent formatting
        - resolution: taxonomy_lookup
    - `on_hand_units` - contains blank rows
        - resolution: replace blank with 0
- duplications & conflicts: 
    - dupe retailer_id + product_sku combos (i.e. CUST-001 + SKU-1001 appears twice)
        - resolution: take row with most recent week_start_date 

`marketing_campaigns_raw` 
- formatting/classification issues: 
    - `platform` - inconsistent classification (Face Space vs FaceSpace)
        - resolution: replace " " with "" 
    - `product_sku` - inconsistent formatting
        - resolution: taxonomy_lookup
    - `channel` - differing values (i.e. Paid Social vs Social) 
        - if budget > 0, replace "Social" with "Paid Social"
    - `region` - inconsistent formatting
        - resolution: taxonomy_lookup
    - `country` - inconsistent formatting
        - resolution: taxonomy_lookup
    - `budget` - non-numeric values mixed in
        - resolution: if value is non-numeric, replace with 0 
    - `video_views` - blanks mixed in
        - resolution: if value is blank, replace with 0 
- duplications & conflicts: 
    - exclude rows where `campaign_start_date` is null - no valid data for these rows

`marketing_performance_raw` 
- formatting/classification issues: 
    - `platform` - inconsistent spacing
        - resolution: replace " " with ""
    - `clicks` - negative values in some cases where this is not realistically possible (i.e. all other delivery metrics are positive)
        - resolution: will handle this in tests


`inventory_snapshots_raw` 
- formatting/classification issues: 
    - `warehouse_id` - inconsistent formatting
        - resolution: taxonomy_lookup ()
    - `on_hand_qty` & `available_qty` - sometimes blank
        - resolution: replace "" with 0
    - `unit_of_measure` - inconsistent classification
        - resolution: taxonomy_lookup 
    - `inventory_status` - inconsistent casing
        - resolution: replace "available" with "Available"
- duplications & conflicts: 
    - duplicate row for [2024-02-29 + WH-001 + SKU-1001]
        - resolution: rows are identical, so just do an overall DISTINCT ON for this particular model output (not the cleanest solution tbh but it will work for now)

`warehouse_locations_raw` 
- formatting/classification issues: 
    - `warehouse_id` - inconsistent, duplicate values
        - resolution: exclude row where warehouse_id = "WH001"
    - `country` - use taxonomy_lookup to standardize

`suppliers_raw` 
- formatting/classification issues: 
    - `supplier_id` - duplicate for SUP-004.
        - resolution: this is a band-aid/not a scalable fix, but i'm just excluding row where supplier_name = 'Delta Plastic Works' and just keeping 'Delta Plastics'...in this _particular_ case this resolves the issue.

`purchase_orders_raw`
- formatting/classification/dupe issues: 
    - `product_sku` - inconsistent formatting 
        - resolution: taxonomy_lookup
    - `warehouse_id` - inconsistent formatting
        - resolution: taxonomy_lookup
    - `po_status` - case inconsistency
        - resolution: taxonomy_lookup (supply_chain -> status)
    - `po_id` - duplicate values 
        - resolution: do DISTINCT ON for final model output


`shipments_raw` 
- formatting/classification/dupe issues: 
    - `product_sku` - needs formatting
    - `warehouse_id` - needs formatting
        - resolution: taxonomy_lookup 
    - `shipment_status` - inconsistent case
        - resolution: replace "delivered" with "Delivered"
    - `tracking_number` - can sometimes be blank! why?
    - `shipment_id` - duplicated 
        - resolution: do DISTINCT ON for final model output


`shipment_events_raw` 
- formatting/classification/dupe issues: 
    - `event_timestamp` - not always formatted as date, one row says 'bad timestamp'
        - resolution: use sqlite date() function to force convert to date type, non-dates will become NULL


`carrier_performance_raw` 
- formatting/classification/dupe issues: 
    - `carrier_id` - duplicate values (CAR-004)
        - resolution: conflicting service_level values, so I am making the executive decision to go with "HarborRoute Express / Air" and exclude the "Harbor Route Express / Express" row at the top