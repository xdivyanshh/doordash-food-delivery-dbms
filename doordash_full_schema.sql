-- ====================================================================
-- DOORDASH DBMS COMPLETE SCHEMA & CONCURRENCY ENGINE
-- Course: Database Management Systems Lab (PBL) - JIIT 3rd Semester
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS postgis;

-- --- SECTION FROM ARTIFACT BLOCK 11 ---
-- =====================================================================

-- DOORDASH RELATIONAL SCHEMA: STAGES 1 & 2 (SUPPLY CHAIN & INVENTORY)

-- =====================================================================



-- 1. STAGE 1: SUPPLIERS DIRECTORY

-- Tracks authenticated raw material vendors, contractual lead times, and reliability ratings.

CREATE TABLE IF NOT EXISTS suppliers (

    supplier_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    supplier_name VARCHAR(120) NOT NULL,

    contact_name VARCHAR(100),

    contact_email VARCHAR(120) UNIQUE NOT NULL,

    contact_phone VARCHAR(20) NOT NULL,

    address_line TEXT NOT NULL,

    city VARCHAR(60) NOT NULL,

    lead_time_days INT NOT NULL DEFAULT 2 CHECK (lead_time_days >= 0),

    reliability_rating NUMERIC(3, 2) DEFAULT 5.00 CHECK (reliability_rating BETWEEN 1.00 AND 5.00),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP

);



-- 2. STAGE 2: STORAGE LOCATIONS

-- Defines storage zones (walk-in freezer, dry pantry) to enforce food safety and proper shelf-life monitoring.

CREATE TABLE IF NOT EXISTS storage_locations (

    location_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    location_name VARCHAR(80) NOT NULL UNIQUE,       -- e.g. 'Walk-in Freezer A', 'Dry Pantry 1'

    zone_type VARCHAR(40) NOT NULL CHECK (zone_type IN ('DRY_STORAGE', 'COLD_STORAGE', 'DEEP_FREEZE', 'AMBIENT')),

    target_temperature_celsius NUMERIC(4, 1),         -- e.g. -18.0 for deep freeze, 3.5 for cold storage

    is_active BOOLEAN NOT NULL DEFAULT TRUE

);



-- 3. STAGE 2: INGREDIENTS CATALOG

-- Raw materials required for cooking dishes (flour, mozzarella, tomato puree, burger patties).

CREATE TABLE IF NOT EXISTS ingredients (

    ingredient_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    ingredient_name VARCHAR(100) NOT NULL,

    category VARCHAR(50) NOT NULL,                   -- e.g. 'Dairy', 'Produce', 'Meat', 'Bakery', 'Packaging'

    unit_of_measure VARCHAR(20) NOT NULL,            -- e.g. 'kg', 'liters', 'grams', 'units'

    cost_per_unit NUMERIC(10, 2) NOT NULL CHECK (cost_per_unit >= 0),

    reorder_threshold NUMERIC(10, 2) NOT NULL CHECK (reorder_threshold >= 0), -- Alert triggered if stock falls below this

    preferred_supplier_id INT REFERENCES suppliers(supplier_id) ON DELETE SET NULL,

    storage_location_id INT NOT NULL REFERENCES storage_locations(location_id) ON DELETE RESTRICT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ingredient_supplier UNIQUE (ingredient_name, preferred_supplier_id)

);



-- B-Tree Indexes for fast filtering and joins

CREATE INDEX IF NOT EXISTS idx_ingredients_category ON ingredients(category);

CREATE INDEX IF NOT EXISTS idx_ingredients_supplier ON ingredients(preferred_supplier_id);

-- --- SECTION FROM ARTIFACT BLOCK 19 ---
-- =====================================================================

-- DOORDASH SCHEMA: STAGES 2 & 3 (PROCUREMENT & BATCH INVENTORY)

-- =====================================================================



-- 4. PURCHASE ORDERS (Header)

CREATE TABLE IF NOT EXISTS purchase_orders (

    po_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    supplier_id INT NOT NULL REFERENCES suppliers(supplier_id) ON DELETE RESTRICT,

    order_status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' 

        CHECK (order_status IN ('DRAFT', 'ORDERED', 'RECEIVED', 'CANCELLED')),

    ordered_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    expected_delivery_date DATE,

    total_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (total_cost >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP

);



-- 5. PURCHASE ORDER ITEMS (Line Items: 1NF Compliant)

CREATE TABLE IF NOT EXISTS purchase_order_items (

    po_item_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    po_id INT NOT NULL REFERENCES purchase_orders(po_id) ON DELETE CASCADE,

    ingredient_id INT NOT NULL REFERENCES ingredients(ingredient_id) ON DELETE RESTRICT,

    quantity_ordered NUMERIC(10, 2) NOT NULL CHECK (quantity_ordered > 0),

    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),

    CONSTRAINT uq_po_ingredient UNIQUE (po_id, ingredient_id)

);



-- 6. INVENTORY BATCHES (Real-Time Stock & Shelf-Life Expiry)

CREATE TABLE IF NOT EXISTS inventory_batches (

    batch_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    ingredient_id INT NOT NULL REFERENCES ingredients(ingredient_id) ON DELETE RESTRICT,

    po_item_id INT REFERENCES purchase_order_items(po_item_id) ON DELETE SET NULL,

    batch_number VARCHAR(50) NOT NULL UNIQUE,

    quantity_received NUMERIC(10, 2) NOT NULL CHECK (quantity_received > 0),

    current_stock_qty NUMERIC(10, 2) NOT NULL CHECK (current_stock_qty >= 0),

    received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    expiry_date DATE NOT NULL,

    is_expired BOOLEAN NOT NULL DEFAULT FALSE

);



-- Indexes for lightning-fast stock checks and expiry searches

CREATE INDEX IF NOT EXISTS idx_po_supplier ON purchase_orders(supplier_id);

CREATE INDEX IF NOT EXISTS idx_inventory_ingredient ON inventory_batches(ingredient_id);

CREATE INDEX IF NOT EXISTS idx_inventory_expiry ON inventory_batches(expiry_date, is_expired);

-- --- SECTION FROM ARTIFACT BLOCK 20 ---
-- =====================================================================
-- DOORDASH SCHEMA: STAGE 4 (RESTAURANTS, MENUS & RECIPE BOM)
-- =====================================================================

-- 7. RESTAURANTS (Commercial Kitchens with PostGIS Spatial Coordinates)
CREATE TABLE IF NOT EXISTS restaurants (
    restaurant_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_name VARCHAR(120) NOT NULL,
    cuisine_type VARCHAR(50) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    address_line TEXT NOT NULL,
    city VARCHAR(60) NOT NULL,
    location GEOMETRY(Point, 4326) NOT NULL,          -- Spatial GPS point (Longitude, Latitude)
    opening_time TIME NOT NULL DEFAULT '09:00:00',
    closing_time TIME NOT NULL DEFAULT '23:00:00',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. MENU ITEMS (Dishes listed on DoorDash)
CREATE TABLE IF NOT EXISTS menu_items (
    item_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id INT NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    item_name VARCHAR(120) NOT NULL,
    item_category VARCHAR(50) NOT NULL,              -- e.g. 'Pizza', 'Burgers', 'Dessert', 'Beverages'
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    preparation_time_mins INT NOT NULL DEFAULT 15 CHECK (preparation_time_mins > 0),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_restaurant_item UNIQUE (restaurant_id, item_name)
);

-- 9. RECIPE BILL OF MATERIALS (BOM)
-- Maps each menu dish to its required proportional raw ingredients
CREATE TABLE IF NOT EXISTS recipe_bom (
    recipe_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_id INT NOT NULL REFERENCES menu_items(item_id) ON DELETE CASCADE,
    ingredient_id INT NOT NULL REFERENCES ingredients(ingredient_id) ON DELETE RESTRICT,
    quantity_required NUMERIC(10, 3) NOT NULL CHECK (quantity_required > 0), -- e.g. 0.250 kg flour
    unit_of_measure VARCHAR(20) NOT NULL,                                     -- 'kg', 'liters', 'units'
    is_critical BOOLEAN NOT NULL DEFAULT TRUE,                               -- If false, dish can be made without it
    CONSTRAINT uq_dish_ingredient UNIQUE (item_id, ingredient_id)
);

-- 10. MULTI-TENANT WIRING (Connecting Kitchens to their Orders & Storage)
ALTER TABLE purchase_orders 
ADD COLUMN restaurant_id INT REFERENCES restaurants(restaurant_id) ON DELETE CASCADE;

ALTER TABLE storage_locations 
ADD COLUMN restaurant_id INT REFERENCES restaurants(restaurant_id) ON DELETE CASCADE;

-- Spatial (GiST) and B-Tree Indexes
CREATE INDEX IF NOT EXISTS idx_restaurants_spatial ON restaurants USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_menu_items_restaurant ON menu_items(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_recipe_bom_item ON recipe_bom(item_id);
CREATE INDEX IF NOT EXISTS idx_recipe_bom_ingredient ON recipe_bom(ingredient_id);
CREATE INDEX IF NOT EXISTS idx_po_restaurant ON purchase_orders(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_storage_restaurant ON storage_locations(restaurant_id);

-- --- SECTION FROM ARTIFACT BLOCK 22 ---
-- =====================================================================
-- DOORDASH SCHEMA: STAGE 5 (CUSTOMERS, ORDERS & DASHERS)
-- =====================================================================

-- 10. CUSTOMERS
CREATE TABLE IF NOT EXISTS customers (
    customer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone_number VARCHAR(20) NOT NULL,
    delivery_address TEXT NOT NULL,
    city VARCHAR(60) NOT NULL,
    default_location GEOMETRY(Point, 4326) NOT NULL,  -- Customer home GPS
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 11. DASHERS (Delivery Drivers with Live GPS)
CREATE TABLE IF NOT EXISTS dashers (
    dasher_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    vehicle_type VARCHAR(30) NOT NULL 
        CHECK (vehicle_type IN ('BICYCLE', 'SCOOTER', 'MOTORCYCLE', 'CAR')),
    current_location GEOMETRY(Point, 4326) NOT NULL,  -- Live Courier GPS coordinates
    is_active BOOLEAN NOT NULL DEFAULT TRUE,          -- On-duty toggle
    is_available BOOLEAN NOT NULL DEFAULT TRUE,       -- Free for dispatch
    reliability_rating NUMERIC(3, 2) DEFAULT 5.00 
        CHECK (reliability_rating BETWEEN 1.00 AND 5.00),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 12. ORDERS (Header)
CREATE TABLE IF NOT EXISTS orders (
    order_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    restaurant_id INT NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE RESTRICT,
    dasher_id INT REFERENCES dashers(dasher_id) ON DELETE SET NULL, -- Assigned on dispatch
    order_status VARCHAR(30) NOT NULL DEFAULT 'PLACED'
        CHECK (order_status IN ('PLACED', 'CONFIRMED', 'PREPARING', 'READY_FOR_PICKUP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED')),
    delivery_destination GEOMETRY(Point, 4326) NOT NULL,
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    delivery_fee NUMERIC(10, 2) NOT NULL DEFAULT 40.00 CHECK (delivery_fee >= 0),
    dasher_tip NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (dasher_tip >= 0),
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    placed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMPTZ
);

-- 13. ORDER ITEMS (Dishes ordered in each order)
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    item_id INT NOT NULL REFERENCES menu_items(item_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),       -- Discrete whole number of dishes!
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    CONSTRAINT uq_order_item UNIQUE (order_id, item_id)
);

-- Spatial GiST Indexes for Ultra-Fast Radius Queries (<50ms Dispatch)
CREATE INDEX IF NOT EXISTS idx_customers_location ON customers USING GIST (default_location);
CREATE INDEX IF NOT EXISTS idx_dashers_location ON dashers USING GIST (current_location);
CREATE INDEX IF NOT EXISTS idx_orders_destination ON orders USING GIST (delivery_destination);

-- B-Tree Indexes for High-Velocity Concurrency Lookups
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_restaurant ON orders(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_orders_dasher ON orders(dasher_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(order_status);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

-- --- SECTION FROM ARTIFACT BLOCK 28 ---
-- =====================================================================
-- DOORDASH SCHEMA: STAGE 6 & LOOP CLOSURE (PAYMENTS & WASTE AUDIT)
-- =====================================================================

-- 14. PAYMENTS (Multi-Split Financial Ledger)
CREATE TABLE IF NOT EXISTS payments (
    payment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INT NOT NULL UNIQUE REFERENCES orders(order_id) ON DELETE RESTRICT,
    payment_method VARCHAR(30) NOT NULL 
        CHECK (payment_method IN ('CREDIT_CARD', 'DEBIT_CARD', 'UPI', 'WALLET', 'CASH_ON_DELIVERY')),
    payment_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (payment_status IN ('PENDING', 'AUTHORIZED', 'SETTLED', 'FAILED', 'REFUNDED')),
    gross_amount NUMERIC(10, 2) NOT NULL CHECK (gross_amount >= 0),
    restaurant_cut NUMERIC(10, 2) NOT NULL CHECK (restaurant_cut >= 0),
    platform_fee NUMERIC(10, 2) NOT NULL CHECK (platform_fee >= 0),
    dasher_payout NUMERIC(10, 2) NOT NULL CHECK (dasher_payout >= 0),
    transaction_reference VARCHAR(120) NOT NULL UNIQUE, -- Bank txn hash
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payment_split_balance 
        CHECK (restaurant_cut + platform_fee + dasher_payout = gross_amount)
);

-- 15. WASTE LOGS (Food Spoilage & Sustainability Mitigation Audit)
CREATE TABLE IF NOT EXISTS waste_logs (
    waste_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id INT NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    ingredient_id INT NOT NULL REFERENCES ingredients(ingredient_id) ON DELETE RESTRICT,
    batch_id INT REFERENCES inventory_batches(batch_id) ON DELETE SET NULL,
    wasted_quantity NUMERIC(10, 2) NOT NULL CHECK (wasted_quantity > 0),
    unit_cost NUMERIC(10, 2) NOT NULL CHECK (unit_cost >= 0),
    total_loss_cost NUMERIC(10, 2) GENERATED ALWAYS AS (wasted_quantity * unit_cost) STORED,
    waste_reason VARCHAR(40) NOT NULL 
        CHECK (waste_reason IN ('EXPIRED', 'SPOILED', 'CONTAMINATED', 'PREP_SPILL', 'DONATION_SURPLUS')),
    action_taken VARCHAR(100) DEFAULT 'DISPOSED' 
        CHECK (action_taken IN ('DISPOSED', 'COMPOSTED', 'DONATED_TO_FOOD_BANK')),
    logged_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Financial & Auditing B-Tree Indexes
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_payments_created ON payments(created_at);
CREATE INDEX IF NOT EXISTS idx_waste_restaurant ON waste_logs(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_waste_ingredient ON waste_logs(ingredient_id);
CREATE INDEX IF NOT EXISTS idx_waste_reason ON waste_logs(waste_reason);

-- --- SECTION FROM ARTIFACT BLOCK 32 ---
-- =====================================================================
-- MILESTONE 2: ACID CONCURRENCY & TWO-PHASE ROW LOCKING (2PL)
-- =====================================================================

CREATE OR REPLACE FUNCTION place_order_atomic(
    p_customer_id INT,
    p_restaurant_id INT,
    p_item_id INT,
    p_quantity INT,
    p_payment_method VARCHAR(30)
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_item_price NUMERIC(10, 2);
    v_subtotal NUMERIC(10, 2);
    v_delivery_fee NUMERIC(10, 2) := 40.00;
    v_dasher_tip NUMERIC(10, 2) := 30.00;
    v_total_amount NUMERIC(10, 2);
    
    v_restaurant_cut NUMERIC(10, 2);
    v_platform_fee NUMERIC(10, 2);
    v_dasher_payout NUMERIC(10, 2);
    
    v_customer_location GEOMETRY(Point, 4326);
    v_dasher_id INT := NULL;
    v_order_id INT;
    v_order_status VARCHAR(30) := 'PLACED';
    
    rec_bom RECORD;
    v_needed_qty NUMERIC(10, 3);
    v_available_qty NUMERIC(10, 2);
    v_remaining_deduct NUMERIC(10, 3);
    rec_batch RECORD;
    v_deduct_amount NUMERIC(10, 2);
BEGIN
    -- 1. VALIDATION: Check customer and dish existence
    SELECT default_location INTO v_customer_location 
    FROM customers WHERE customer_id = p_customer_id;
    IF v_customer_location IS NULL THEN
        RAISE EXCEPTION 'Customer ID % not found.', p_customer_id;
    END IF;

    SELECT price INTO v_item_price 
    FROM menu_items 
    WHERE item_id = p_item_id AND restaurant_id = p_restaurant_id AND is_available = TRUE;
    IF v_item_price IS NULL THEN
        RAISE EXCEPTION 'Menu item ID % is unavailable or does not belong to Restaurant ID %.', p_item_id, p_restaurant_id;
    END IF;

    -- 2. RECIPE BOM & TWO-PHASE ROW-LEVEL LOCKING (2PL Growing Phase)
    -- Loop through each raw ingredient required by the dish
    FOR rec_bom IN 
        SELECT ingredient_id, quantity_required 
        FROM recipe_bom 
        WHERE item_id = p_item_id AND is_critical = TRUE
    LOOP
        v_needed_qty := rec_bom.quantity_required * p_quantity;

        -- ROW-LEVEL LOCK: Lock active batches for this ingredient exclusively (2PL Phase 1)!
        PERFORM 1
        FROM inventory_batches
        WHERE ingredient_id = rec_bom.ingredient_id 
          AND is_expired = FALSE 
          AND current_stock_qty > 0
        FOR UPDATE;

        -- Verify stock sufficiency across locked batches
        SELECT COALESCE(SUM(current_stock_qty), 0) INTO v_available_qty
        FROM inventory_batches
        WHERE ingredient_id = rec_bom.ingredient_id 
          AND is_expired = FALSE 
          AND current_stock_qty > 0;

        -- Verify stock sufficiency
        IF v_available_qty < v_needed_qty THEN
            RAISE EXCEPTION 'INSUFFICIENT STOCK: Ingredient ID % requires % kg/L, but only % available.', 
                rec_bom.ingredient_id, v_needed_qty, v_available_qty;
        END IF;

        -- FIFO DEDUCTION: Deduct stock from earliest-expiring batches first
        v_remaining_deduct := v_needed_qty;
        FOR rec_batch IN 
            SELECT batch_id, current_stock_qty 
            FROM inventory_batches
            WHERE ingredient_id = rec_bom.ingredient_id 
              AND is_expired = FALSE 
              AND current_stock_qty > 0
            ORDER BY expiry_date ASC
            FOR UPDATE
        LOOP
            IF v_remaining_deduct <= 0 THEN
                EXIT;
            END IF;

            IF rec_batch.current_stock_qty <= v_remaining_deduct THEN
                v_deduct_amount := rec_batch.current_stock_qty;
                v_remaining_deduct := v_remaining_deduct - v_deduct_amount;
                UPDATE inventory_batches 
                SET current_stock_qty = 0 
                WHERE batch_id = rec_batch.batch_id;
            ELSE
                v_deduct_amount := v_remaining_deduct;
                UPDATE inventory_batches 
                SET current_stock_qty = current_stock_qty - v_deduct_amount 
                WHERE batch_id = rec_batch.batch_id;
                v_remaining_deduct := 0;
            END IF;
        END LOOP;
    END LOOP;

    -- 3. FINANCIAL CALCULATIONS
    v_subtotal := v_item_price * p_quantity;
    v_total_amount := v_subtotal + v_delivery_fee + v_dasher_tip;
    
    -- Multi-split accounting reconciliation
    v_restaurant_cut := ROUND(v_subtotal * 0.80, 2);       -- 80% food sales
    v_platform_fee := ROUND(v_subtotal * 0.20, 2);         -- 20% commission
    v_dasher_payout := v_total_amount - (v_restaurant_cut + v_platform_fee); -- Balance: fee + 100% tip

    -- 4. SPATIAL COURIER DISPATCH via PostGIS (Sub-50ms Radius Search)
    SELECT d.dasher_id INTO v_dasher_id
    FROM dashers d
    WHERE d.is_active = TRUE
      AND d.is_available = TRUE
      AND ST_DWithin(d.current_location::geography, (SELECT location::geography FROM restaurants WHERE restaurant_id = p_restaurant_id), 5000)
    ORDER BY ST_Distance(d.current_location::geography, (SELECT location::geography FROM restaurants WHERE restaurant_id = p_restaurant_id)) ASC
    LIMIT 1
    FOR UPDATE; -- Lock driver exclusively so concurrent checkouts cannot double-assign them!

    IF v_dasher_id IS NOT NULL THEN
        v_order_status := 'CONFIRMED';
        UPDATE dashers SET is_available = FALSE WHERE dasher_id = v_dasher_id;
    END IF;

    -- 5. PERSIST ORDER & ORDER ITEMS
    INSERT INTO orders (
        customer_id, restaurant_id, dasher_id, order_status,
        delivery_destination, subtotal, delivery_fee, dasher_tip, total_amount
    )
    VALUES (
        p_customer_id, p_restaurant_id, v_dasher_id, v_order_status,
        v_customer_location, v_subtotal, v_delivery_fee, v_dasher_tip, v_total_amount
    )
    RETURNING order_id INTO v_order_id;

    INSERT INTO order_items (order_id, item_id, quantity, unit_price, subtotal)
    VALUES (v_order_id, p_item_id, p_quantity, v_item_price, v_subtotal);

    -- 6. SETTLE MULTI-SPLIT PAYMENT LEDGER
    INSERT INTO payments (
        order_id, payment_method, payment_status, gross_amount,
        restaurant_cut, platform_fee, dasher_payout, transaction_reference, settled_at
    )
    VALUES (
        v_order_id, p_payment_method, 'SETTLED', v_total_amount,
        v_restaurant_cut, v_platform_fee, v_dasher_payout,
        'TXN-' || v_order_id || '-' || EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::BIGINT,
        CURRENT_TIMESTAMP
    );

    -- 7. RETURN COMPREHENSIVE ATOMIC RESULT
    RETURN jsonb_build_object(
        'status', 'SUCCESS',
        'order_id', v_order_id,
        'order_status', v_order_status,
        'currency', 'INR (₹)',
        'dasher_id', v_dasher_id,
        'total_amount', v_total_amount,
        'restaurant_cut', v_restaurant_cut,
        'platform_fee', v_platform_fee,
        'dasher_payout', v_dasher_payout,
        'message', 'Transaction committed: Recipe deducted via FIFO, Dasher matched via PostGIS, and Payment settled.'
    );
END;
$$;




-- =====================================================================

-- =====================================================================
-- AUTOMATED EXPIRY & WASTE QUARANTINE TRIGGER SYSTEM
-- Deliverable: Automated Expiry Triggers (Divyansh Agarwal - 2501030124)
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_audit_expired_inventory_batch()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_restaurant_id INT;
    v_unit_cost NUMERIC(10, 2);
BEGIN
    -- Only trigger when an active, unexpired batch with positive stock is marked expired
    IF NEW.is_expired = TRUE AND (OLD.is_expired = FALSE OR OLD.is_expired IS NULL) THEN
        IF NEW.current_stock_qty > 0 THEN
            -- 1. Fetch unit cost from ingredients catalog
            SELECT cost_per_unit INTO v_unit_cost
            FROM ingredients
            WHERE ingredient_id = NEW.ingredient_id;
            
            IF v_unit_cost IS NULL THEN
                v_unit_cost := 0.00;
            END IF;

            -- 2. Resolve restaurant_id (via PO or via storage location)
            SELECT po.restaurant_id INTO v_restaurant_id
            FROM purchase_orders po
            JOIN purchase_order_items poi ON po.po_id = poi.po_id
            WHERE poi.po_item_id = NEW.po_item_id;

            IF v_restaurant_id IS NULL THEN
                SELECT sl.restaurant_id INTO v_restaurant_id
                FROM ingredients ing
                JOIN storage_locations sl ON ing.storage_location_id = sl.location_id
                WHERE ing.ingredient_id = NEW.ingredient_id;
            END IF;

            IF v_restaurant_id IS NULL THEN
                SELECT restaurant_id INTO v_restaurant_id FROM restaurants LIMIT 1;
            END IF;

            -- 3. Persist financial audit write-off into waste_logs
            INSERT INTO waste_logs (
                restaurant_id,
                ingredient_id,
                batch_id,
                wasted_quantity,
                unit_cost,
                waste_reason,
                action_taken,
                logged_at
            ) VALUES (
                v_restaurant_id,
                NEW.ingredient_id,
                NEW.batch_id,
                NEW.current_stock_qty,
                v_unit_cost,
                'EXPIRED',
                'DISPOSED',
                CURRENT_TIMESTAMP
            );

            -- 4. Safety Quarantine: zero out remaining active inventory
            NEW.current_stock_qty := 0.00;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_expiry_audit ON inventory_batches;
CREATE TRIGGER trg_inventory_expiry_audit
BEFORE UPDATE ON inventory_batches
FOR EACH ROW
EXECUTE FUNCTION fn_audit_expired_inventory_batch();

-- AUTOMATED SWEEP PROCEDURE: Scans all batches and flags expired lots
DROP FUNCTION IF EXISTS sweep_and_quarantine_expired_batches();
CREATE OR REPLACE FUNCTION sweep_and_quarantine_expired_batches()
RETURNS TABLE(quarantined_batches INT, total_loss_amount NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT := 0;
    v_loss NUMERIC := 0.00;
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT batch_id, current_stock_qty
        FROM inventory_batches
        WHERE expiry_date < CURRENT_DATE 
          AND is_expired = FALSE
          AND current_stock_qty > 0
    LOOP
        -- Updating is_expired fires trg_inventory_expiry_audit automatically!
        UPDATE inventory_batches
        SET is_expired = TRUE
        WHERE batch_id = rec.batch_id;
        
        v_count := v_count + 1;
    END LOOP;

    -- Aggregate today's expired losses
    SELECT COALESCE(SUM(total_loss_cost), 0.00) INTO v_loss
    FROM waste_logs
    WHERE waste_reason = 'EXPIRED'
      AND DATE(logged_at) = CURRENT_DATE;

    RETURN QUERY SELECT v_count, v_loss;
END;
$$;
