Sammy Stewart
July 28, 2026

Hasbro - Senior Analytics Engineer Take-Home Assessment


### Project Structure Overview

Models: built in two phases
- First, the staging models (prefixed with stg_), which do basic cleanup & transormation of the _raw data tables.
    - I've used the taxonomy_lookup table where possible as a means of normalizing the dimensional data.
    - I've then layered on some additional ad hoc normalization steps to fill in some of the remaining gaps (including additional renaming/reclassification, data type formatting, string trimming/cleaning, basic de-duplication). 
    - Specifics on all the additional assumptions/normalization steps I took for each staging model can be found at the end of this README. 
- Second, the operational models (prefixed with op_), which are built from the staging models. The operational models handle the more complex transformation/synthesis/joining required for final consumption & analysis. 

Tests: built in two phases, aligning with the model phases (stg vs op)
- For failed tests, for the time being I have set the default severity level to 'warn'...this is because I am still getting acclimated with the context surrounding teh data; ultimately I would want to level up the severity to 'fail' once these models were deployed to production...but first I need to understand WHY the ones that are failing are failing.
- For now, depending on the specifics of the failure, failed tests will either require more troubleshooting on the back-end, OR would require further exploration across the company more broadly (i.e. checking w/ stakeholders abt what the flags actually mean and how to handle them moving forward).

More detail on the specific tests can be found in the below `Tests` section.

Follow-up questions for stakeholders stemming from these test outcomes can be found in the `Initital Questions` section.

A summary of some of my initial takeaways, after looking at the synthesized data, can be found in the `Topline Takeaways` section.

Notes on things I have NOT done in my project setup here (but would like to do in an ideal world): 
- No CI/CD prod vs dev considerations - SQLite didn't immediately lend itself to this sort of set up.
- Preferably I would partition the various models inside medallion architecture (i.e. staging models would be in bronze, maybe a silver layer, and final consumption-ready marts in gold), but I haven't done that here either, for similar SQLite related reasons (couldnt immediately figure out how to create diff db schema)...so instead I've just used consistent prefixes when naming models to identify what category they fall into (stg_ or op_).
- Not worrying about linting / SQLFluff stuff for now, either.
- I would like to create some more dbt macros, to handle some of the additional normalization/classification steps (at certain points I felt like my code was starting to get a bit verbose, model to model...)
- Didn't have time to ensure fully-consistent decimal place conventions across all numeric fields.



### Tests

General testing approach: I used a mix of simple yml tests and more complex tests stored as custom sql in the tests subfolder. Both sets of tests are evaluated on `dbt build`.

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
- For 

Operational models - complex tests:
- Orphan keys showing up anywhere (sku / taxonomy code / campaign / supplier etc)? Flag if true. 



### Initial Questions

Initial questions (stemming from any final tests that failed - ideally all these questions will be resolved before any final analysis is presented). 

Staging questions:
    - In marketing performance data, there's a row where clicks = -10 which doesn't make sense. How to handle this?
    - In the inventory data, there's a row where the on-hand & available quantities are negative (-25 and -75, respectively). Is this possible, and if so, what does it mean?

Operational questions: 



### Topline Takeaways

Topline takeaways: 
    - Based on the data, I am seeing a couple major trends that stand out.



------------------------------------------------------------------
------------------------------------------------------------------

### Raw Tables - Data Quality Audit for Staging Models

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