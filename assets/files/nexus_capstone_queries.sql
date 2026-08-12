/* =====================================================================
   NEXUS RETAIL GROUP - SQL CAPSTONE PROJECT
   10Alytics | Retail Analytics Specialization
   Author: Tomiwa (Pod Astra)

   PURPOSE
   -------
   Nexus Retail Group (consumer electronics retailer) is losing margin
   to inflation-driven demand swings, mistimed promotions, and rigid
   safety-stock rules. As Supply Chain Consultant, this script answers
   the four "Key Analytical Question" groups from the capstone brief:

     1. Inflation & GDP Impact Analysis
     2. Promo & Demand Alignment Analysis
     3. Inventory & Overstock Analysis
     4. Profit Margin & Cost Analysis

   DATA MODEL NOTES
   -----------------
   - sales        : one row per TRANSACTION (salesid = PK). inventoryquantity
                    is the stock level recorded AT THAT TRANSACTION - i.e. a
                    snapshot of leftover/unsold stock, not "units sold".
                    productcost = unit cost of the item.
   - product      : one row per product, category + whether a promotion
                    was active (promotions = 'Yes'/'No').
   - factors      : macro-economic snapshot per date (gdp, inflationrate,
                    seasonalfactor - where 1.00 = average demand,
                    <1.00 = below-average/slow season, >1.00 = peak season).

   Because there's no explicit "units sold" column, "sales volume" is
   measured as COUNT(salesid) - i.e. number of sales transactions - and
   "deadstock value" is measured as SUM(inventoryquantity * productcost),
   i.e. the cash value sitting unsold in the warehouse.

   Quick reference (from data profiling):
     inflationrate range ~1.00 - 5.00, avg ~3.0
     gdp            range ~15,047 - 24,997, avg ~20,042
     seasonalfactor range ~0.80 - 1.20, avg ~1.00
     product categories: Electronics, Laptops, SmartPhones, Home_Appliances
   ===================================================================== */


/* =====================================================================
   SECTION 1: INFLATION & GDP IMPACT ANALYSIS
   Goal: show how economic shifts hurt sales, freeze cash in stock,
   and shrink profit.
   ===================================================================== */

-- 1.1 PRODUCT PERFORMANCE
-- Which product categories suffer the biggest drop in sales volume
-- (transaction count) when inflation rises?
-- Method: bucket every sale into a Low / Medium / High inflation band
-- (using thirds of the observed range), then compare transaction counts
-- per category across bands to see which categories fall off hardest
-- as inflation climbs.
SELECT
    p.productcategory,
    COUNT(*) FILTER (WHERE f.inflationrate < 2.33)                     AS low_inflation_sales,
    COUNT(*) FILTER (WHERE f.inflationrate BETWEEN 2.33 AND 3.66)      AS medium_inflation_sales,
    COUNT(*) FILTER (WHERE f.inflationrate > 3.66)                     AS high_inflation_sales,
    -- % change in sales volume from low-inflation to high-inflation periods
    ROUND(
        100.0 * (
            COUNT(*) FILTER (WHERE f.inflationrate > 3.66)
            - COUNT(*) FILTER (WHERE f.inflationrate < 2.33)
        ) / NULLIF(COUNT(*) FILTER (WHERE f.inflationrate < 2.33), 0),
        1
    ) AS pct_change_low_to_high_inflation
FROM sales s
JOIN product p ON p.productid = s.productid
JOIN factors f ON f.salesdate = s.salesdate
GROUP BY p.productcategory
ORDER BY pct_change_low_to_high_inflation ASC;   -- most negative = biggest drop


-- 1.2 DEADSTOCK CAPITAL
-- How much company cash is tied up in unsold warehouse inventory
-- during low-GDP months?
-- Method: flag months where GDP is below the overall average, then sum
-- the dollar value of leftover stock (inventoryquantity * productcost)
-- recorded during those months, broken out by category.
WITH avg_gdp AS (
    SELECT AVG(gdp) AS overall_avg_gdp FROM factors
)
SELECT
    p.productcategory,
    ROUND(SUM(s.inventoryquantity * s.productcost), 2) AS deadstock_value_low_gdp_months,
    COUNT(*)                                            AS transactions_in_low_gdp_months
FROM sales s
JOIN product p ON p.productid = s.productid
JOIN factors f ON f.salesdate = s.salesdate
CROSS JOIN avg_gdp
WHERE f.gdp < avg_gdp.overall_avg_gdp        -- "low-GDP" = below-average GDP
GROUP BY p.productcategory
ORDER BY deadstock_value_low_gdp_months DESC;


/* =====================================================================
   SECTION 2: PROMO & DEMAND ALIGNMENT ANALYSIS
   Goal: see if ads actually boost sales, stop wasteful marketing spend
   during naturally slow seasons, and identify products that sell well
   on their own.
   ===================================================================== */

-- 2.1 PROMO ROI
-- Do promotional campaigns actually drive a clear lift in sales volume,
-- or are they wasting budget?
-- Method: compare average transactions per product between promoted
-- ('Yes') and non-promoted ('No') items, by category.
SELECT
    p.productcategory,
    p.promotions,
    COUNT(*)                                            AS total_sales_transactions,
    COUNT(DISTINCT p.productid)                          AS distinct_products,
    ROUND(COUNT(*)::numeric / COUNT(DISTINCT p.productid), 2) AS avg_sales_per_product
FROM sales s
JOIN product p ON p.productid = s.productid
GROUP BY p.productcategory, p.promotions
ORDER BY p.productcategory, p.promotions;


-- 2.2 SEASONAL TIMING
-- Are we spending money on advertisements during slow seasons when
-- customer demand is naturally low?
-- Method: seasonalfactor < 1.00 indicates below-average/slow demand.
-- Flag promoted transactions that happened during those slow-demand
-- dates - this is wasted ad spend.
SELECT
    p.productcategory,
    COUNT(*) AS promo_transactions_during_slow_season,
    ROUND(AVG(f.seasonalfactor), 2) AS avg_seasonal_factor_during_these_sales
FROM sales s
JOIN product p ON p.productid = s.productid
JOIN factors f ON f.salesdate = s.salesdate
WHERE p.promotions = 'Yes'
  AND f.seasonalfactor < 1.00        -- below-average demand period
GROUP BY p.productcategory
ORDER BY promo_transactions_during_slow_season DESC;


-- 2.3 CORE PRODUCTS
-- Which product categories bring in steady sales anyway, even without
-- any active marketing help?
-- Method: look only at non-promoted ('No') transactions and rank
-- categories by sales volume - the strongest performers here don't
-- need ad spend to move.
SELECT
    p.productcategory,
    COUNT(*) AS sales_without_promotion
FROM sales s
JOIN product p ON p.productid = s.productid
WHERE p.promotions = 'No'
GROUP BY p.productcategory
ORDER BY sales_without_promotion DESC;


/* =====================================================================
   SECTION 3: INVENTORY & OVERSTOCK ANALYSIS
   Goal: identify products stuck in the warehouse, pinpoint when
   inventory piles up, and stop overstocking from draining cash.
   ===================================================================== */

-- 3.1 SLOW-MOVING STOCK
-- Which products are sitting heavily in warehouse inventory with
-- little to no sales activity?
-- Method: for each product, compare how many times it sold (low =
-- weak demand) against its average leftover inventory (high = piling
-- up). Products with few transactions but high average stock are
-- the slow movers.
SELECT
    s.productid,
    p.productcategory,
    COUNT(*)                              AS number_of_sales,
    ROUND(AVG(s.inventoryquantity), 1)    AS avg_leftover_inventory,
    ROUND(AVG(s.inventoryquantity) / NULLIF(COUNT(*), 0), 2) AS stagnation_ratio -- higher = slower moving
FROM sales s
JOIN product p ON p.productid = s.productid
GROUP BY s.productid, p.productcategory
HAVING COUNT(*) <= 3                      -- low transaction count = weak demand
ORDER BY avg_leftover_inventory DESC
LIMIT 20;


-- 3.2 PEAK DEADSTOCK MONTHS
-- In which months of the year do we consistently get stuck with the
-- highest amount of unsold stock?
-- Method: sum leftover inventory by calendar month (across all years)
-- to find the recurring seasonal peak(s).
SELECT
    s.sales_month,
    SUM(s.inventoryquantity)              AS total_leftover_inventory,
    ROUND(AVG(s.inventoryquantity), 1)    AS avg_leftover_inventory_per_sale
FROM sales s
GROUP BY s.sales_month
ORDER BY total_leftover_inventory DESC;


-- 3.3 WAREHOUSE BOTTLENECKS
-- Which specific product categories are taking up the most warehouse
-- space and draining our holding costs?
-- Method: total leftover inventory units by category - the biggest
-- volume is the biggest space/holding-cost drain.
SELECT
    p.productcategory,
    SUM(s.inventoryquantity)              AS total_units_in_warehouse,
    ROUND(AVG(s.inventoryquantity), 1)    AS avg_units_per_transaction
FROM sales s
JOIN product p ON p.productid = s.productid
GROUP BY p.productcategory
ORDER BY total_units_in_warehouse DESC;


/* =====================================================================
   SECTION 4: PROFIT MARGIN & COST ANALYSIS
   Goal: find out if rising costs are eating into profits, which
   expensive items are freezing cash in stock, and which products cost
   more but sell less.
   ===================================================================== */

-- 4.1 HIGH-COST DEADSTOCK
-- Which expensive product categories are draining the most company
-- cash when they sit unsold?
-- Method: value of leftover inventory (inventoryquantity * productcost)
-- by category, plus the average unit cost, to show where the most
-- expensive dead capital is concentrated.
SELECT
    p.productcategory,
    ROUND(AVG(s.productcost), 2)                       AS avg_unit_cost,
    SUM(s.inventoryquantity)                            AS total_leftover_units,
    ROUND(SUM(s.inventoryquantity * s.productcost), 2)  AS total_deadstock_value
FROM sales s
JOIN product p ON p.productid = s.productid
GROUP BY p.productcategory
ORDER BY total_deadstock_value DESC;


/* =====================================================================
   END OF SCRIPT
   ===================================================================== */
