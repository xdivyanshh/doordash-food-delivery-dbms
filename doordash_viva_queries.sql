-- ============================================================================
-- DOORDASH DBMS: 5 VIVA & LAB EVALUATION BENCHMARK QUERIES
-- Jaypee Institute of Information Technology (JIIT), Noida
-- Department of Computer Science & Engineering - 3rd Semester DBMS Lab (PBL)
-- Student: Divyansh Agarwal (Enrolment No: 2501030124)
-- Engine: PostgreSQL 17 + PostGIS 3.6 | Database: doordash_db
-- ============================================================================

-- ============================================================================
-- QUERY 1: PostGIS Geodesic Proximity Dispatch (Spatial R-Tree Index Proof)
-- Evaluates real Earth-curvature distance (in meters) between all active dashers
-- and DoorDash Kitchen #1 (Sector 62), selecting the nearest courier.
-- ============================================================================
SELECT 
    d.dasher_id,
    d.first_name || ' ' || d.last_name AS dasher_name,
    d.vehicle_type,
    d.reliability_rating,
    r.restaurant_name,
    ROUND(ST_Distance(d.current_location::geography, r.location::geography)::numeric, 2) AS distance_in_meters,
    CASE 
        WHEN ST_DWithin(d.current_location::geography, r.location::geography, 5000) THEN 'ELIGIBLE (Within 5km)'
        ELSE 'OUT OF RANGE'
    END AS dispatch_eligibility
FROM dashers d
CROSS JOIN restaurants r
WHERE r.restaurant_id = 1
  AND d.is_active = TRUE
ORDER BY distance_in_meters ASC;


-- ============================================================================
-- QUERY 2: FIFO Inventory Batch Expiration & Risk Monitoring
-- Scans active inventory batches and calculates remaining shelf-life days,
-- ordering by expiry date so kitchen managers know which batches must be used first.
-- ============================================================================
SELECT 
    b.batch_id,
    b.batch_number,
    i.ingredient_name,
    i.category,
    b.current_stock_qty || ' ' || i.unit_of_measure AS available_stock,
    b.expiry_date,
    (b.expiry_date - CURRENT_DATE) AS days_until_expiry,
    CASE 
        WHEN (b.expiry_date - CURRENT_DATE) < 0 THEN 'EXPIRED (Must Quarantine)'
        WHEN (b.expiry_date - CURRENT_DATE) <= 3 THEN 'CRITICAL (Use Today / FIFO)'
        WHEN (b.expiry_date - CURRENT_DATE) <= 7 THEN 'WARNING (Near Expiry)'
        ELSE 'FRESH'
    END AS health_status
FROM inventory_batches b
JOIN ingredients i ON b.ingredient_id = i.ingredient_id
WHERE b.is_expired = FALSE
ORDER BY b.expiry_date ASC, b.current_stock_qty DESC;


-- ============================================================================
-- QUERY 3: Multi-Split Financial Settlement & Conservation of Money Proof
-- Verifies the 3-way ledger split across Restaurant (80%), Platform (20%),
-- and Dasher (Delivery Fee + 100% Tip), proving ZERO financial leakage.
-- ============================================================================
SELECT 
    p.payment_id,
    p.order_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    p.payment_method,
    p.gross_amount,
    p.restaurant_cut,
    p.platform_fee,
    p.dasher_payout,
    -- Prove conservation of money:
    (p.restaurant_cut + p.platform_fee + p.dasher_payout) AS sum_of_splits,
    ROUND(p.gross_amount - (p.restaurant_cut + p.platform_fee + p.dasher_payout), 2) AS leakage_discrepancy,
    p.transaction_reference,
    p.payment_status
FROM payments p
JOIN orders o ON p.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
ORDER BY p.payment_id ASC;


-- ============================================================================
-- QUERY 4: Recipe Bill of Materials (BOM) Costing & Gross Profit Margins
-- Computes raw ingredient food cost for each dish by aggregating BOM quantities
-- and ingredient unit costs, deriving exact kitchen gross profit margins (%).
-- ============================================================================
SELECT 
    m.item_id,
    m.item_name,
    m.item_category,
    m.price AS menu_selling_price,
    ROUND(SUM(b.quantity_required * i.cost_per_unit)::numeric, 2) AS raw_food_cost,
    ROUND((m.price - SUM(b.quantity_required * i.cost_per_unit))::numeric, 2) AS gross_profit_per_dish,
    ROUND((((m.price - SUM(b.quantity_required * i.cost_per_unit)) / m.price) * 100)::numeric, 1) || '%' AS gross_margin_pct
FROM menu_items m
JOIN recipe_bom b ON m.item_id = b.item_id
JOIN ingredients i ON b.ingredient_id = i.ingredient_id
GROUP BY m.item_id, m.item_name, m.item_category, m.price
ORDER BY gross_profit_per_dish DESC;


-- ============================================================================
-- QUERY 5: Spoilage Audit & Write-Off Ledger (Divyansh's Synopsis Deliverable)
-- Audits all quarantine actions triggered automatically by trg_inventory_expiry_audit,
-- grouping by reason, action taken, and dollar loss write-offs.
-- ============================================================================
SELECT 
    w.waste_id,
    r.restaurant_name,
    i.ingredient_name,
    b.batch_number,
    w.wasted_quantity || ' ' || i.unit_of_measure AS quantity_scrapped,
    w.unit_cost,
    '₹' || w.total_loss_cost AS financial_loss,
    w.waste_reason,
    w.action_taken,
    w.logged_at
FROM waste_logs w
JOIN restaurants r ON w.restaurant_id = r.restaurant_id
JOIN ingredients i ON w.ingredient_id = i.ingredient_id
LEFT JOIN inventory_batches b ON w.batch_id = b.batch_id
ORDER BY w.logged_at DESC;
