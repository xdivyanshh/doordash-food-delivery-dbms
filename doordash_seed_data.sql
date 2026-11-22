-- ============================================================================
-- DOORDASH DBMS: REALISTIC PRODUCTION SEED DATASET (JIIT NOIDA REGION)
-- Semester 3 DBMS Lab (PBL) - Jaypee Institute of Information Technology, Noida
-- Author: Divyansh Agarwal (Enrolment No: 2501030124)
-- Engine: PostgreSQL 17 + PostGIS 3.6
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- STEP 0: CLEAN RESET (Idempotent Re-runs)
-- ----------------------------------------------------------------------------
TRUNCATE TABLE 
    waste_logs,
    payments,
    order_items,
    orders,
    dashers,
    customers,
    recipe_bom,
    menu_items,
    inventory_batches,
    purchase_order_items,
    purchase_orders,
    ingredients,
    storage_locations,
    suppliers,
    restaurants
RESTART IDENTITY CASCADE;

-- ----------------------------------------------------------------------------
-- STEP 1: RESTAURANTS (Real Noida Coordinates Mapped to Sector 62 & 63)
-- ----------------------------------------------------------------------------
INSERT INTO restaurants (
    restaurant_name, cuisine_type, phone_number, address_line, city, 
    location, opening_time, closing_time, is_active
) VALUES
-- Restaurant 1: DoorDash Kitchen #1 (Sector 62 Hub, ~400m from JIIT Campus)
('DoorDash Kitchen #1 (Sector 62)', 'Italian & American Gourmet', '+91-120-4567890', 
 'C-56/12, Institutional Area, Sector 62', 'Noida', 
 ST_SetSRID(ST_MakePoint(77.3670, 28.6280), 4326), '09:00:00', '23:30:00', TRUE),

-- Restaurant 2: Haldiram Quick Bites (Sector 63, ~1.4 km from JIIT Campus)
('Haldiram Quick Bites (Sector 63)', 'North Indian & Street Food', '+91-120-2401122', 
 'A-8, Electronic City, Sector 63', 'Noida', 
 ST_SetSRID(ST_MakePoint(77.3820, 28.6310), 4326), '08:30:00', '23:00:00', TRUE),

-- Restaurant 3: The Burger Club (Sector 62 Commercial Complex)
('The Burger Club (Sector 62)', 'American Burgers & Shakes', '+91-120-4321987', 
 'B-9, Ground Floor, Sector 62', 'Noida', 
 ST_SetSRID(ST_MakePoint(77.3655, 28.6272), 4326), '10:00:00', '01:00:00', TRUE);

-- ----------------------------------------------------------------------------
-- STEP 2: SUPPLIERS (Dairy, Fresh Produce, Bakery, Eco-Packaging)
-- ----------------------------------------------------------------------------
INSERT INTO suppliers (
    supplier_name, contact_name, contact_email, contact_phone, 
    address_line, city, lead_time_days, reliability_rating, is_active
) VALUES
('Amul Dairy Federation Distro', 'Rajesh Sharma', 'orders@amul-noida.in', '+91-9811023451', 'Plot B-12, Sector 63 Logistics Park', 'Noida', 1, 4.95, TRUE),
('Mother Dairy Fresh Produce', 'Sanjay Verma', 'supplies@motherdairy.com', '+91-9871122334', 'Sector 11 Metro Road', 'Noida', 1, 4.80, TRUE),
('Bakers Choice Gourmet Flour & Buns', 'Deepak Gupta', 'contact@bakerschoice.in', '+91-9910045678', 'Industrial Area Phase 2', 'Noida', 2, 4.88, TRUE),
('EcoPack Sustainable Solutions', 'Pooja Nair', 'sales@ecopack.in', '+91-9820054321', 'Sector 58 Tech Zone', 'Noida', 3, 4.90, TRUE);

-- ----------------------------------------------------------------------------
-- STEP 3: STORAGE LOCATIONS (Temperature-Controlled HACCP Zones)
-- ----------------------------------------------------------------------------
INSERT INTO storage_locations (
    restaurant_id, location_name, zone_type, target_temperature_celsius, is_active
) VALUES
(1, 'Walk-in Deep Freezer A', 'DEEP_FREEZE', -18.0, TRUE),
(1, 'Dairy & Cheese Chiller B', 'COLD_STORAGE', 3.5, TRUE),
(1, 'Fresh Produce Crisper C', 'COLD_STORAGE', 4.0, TRUE),
(1, 'Dry Pantry & Flour Silo 1', 'DRY_STORAGE', 22.0, TRUE),
(1, 'Packaging Ambient Warehouse', 'AMBIENT', 24.0, TRUE);

-- ----------------------------------------------------------------------------
-- STEP 4: INGREDIENTS (BOM Components with Target Unit Costs in INR)
-- ----------------------------------------------------------------------------
INSERT INTO ingredients (
    ingredient_name, category, unit_of_measure, cost_per_unit, 
    reorder_threshold, preferred_supplier_id, storage_location_id
) VALUES
('Mozzarella Cheese Blend', 'Dairy', 'kg', 420.00, 5.00, 1, 2),
('Fresh Russet Potatoes', 'Produce', 'kg', 28.00, 15.00, 2, 3),
('Artisan Beef Patty', 'Meat', 'kg', 480.00, 8.00, 1, 1),
('Brioche Burger Buns', 'Bakery', 'units', 15.00, 20.00, 3, 4),
('San Marzano Tomato Sauce', 'Produce', 'kg', 120.00, 6.00, 2, 4),
('Smoked Gouda Cheese', 'Dairy', 'kg', 550.00, 3.00, 1, 2),
('Heavy Dairy Cream (35% Fat)', 'Dairy', 'liters', 180.00, 4.00, 1, 2),
('Eco-Kraft Delivery Meal Box', 'Packaging', 'units', 8.50, 50.00, 4, 5);

-- ----------------------------------------------------------------------------
-- STEP 5: PURCHASE ORDERS & LINE ITEMS (Inbound Procurement Records in INR)
-- ----------------------------------------------------------------------------
INSERT INTO purchase_orders (
    restaurant_id, supplier_id, order_status, ordered_at, expected_delivery_date, total_cost
) VALUES
(1, 1, 'RECEIVED', CURRENT_TIMESTAMP - INTERVAL '5 days', CURRENT_DATE - INTERVAL '4 days', 4200.00),
(1, 2, 'RECEIVED', CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_DATE - INTERVAL '3 days', 1400.00),
(1, 1, 'RECEIVED', CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_DATE - INTERVAL '2 days', 2400.00),
(1, 3, 'RECEIVED', CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_DATE - INTERVAL '1 day', 1500.00),
(1, 1, 'RECEIVED', CURRENT_TIMESTAMP - INTERVAL '10 days', CURRENT_DATE - INTERVAL '9 days', 720.00);

INSERT INTO purchase_order_items (
    po_id, ingredient_id, quantity_ordered, unit_price
) VALUES
(1, 1, 10.00, 420.00), -- 10kg Mozzarella
(2, 2, 50.00, 28.00),  -- 50kg Potatoes
(3, 3, 5.00, 480.00),  -- 5kg Beef Patties
(4, 4, 100.00, 15.00), -- 100 Brioche Buns
(5, 7, 4.00, 180.00);  -- 4 Liters Heavy Cream (Will be expired)

-- ----------------------------------------------------------------------------
-- STEP 6: INVENTORY BATCHES (FIFO Demonstration & Trigger Test)
-- ----------------------------------------------------------------------------
-- Batch #1: Mozzarella (Expiring in 2 days -> Depleted FIRST by FIFO)
INSERT INTO inventory_batches (
    ingredient_id, po_item_id, batch_number, quantity_received, 
    current_stock_qty, received_at, expiry_date, is_expired
) VALUES
(1, 1, 'BATCH-MOZZ-2026-A1', 5.00, 2.00, CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_DATE + INTERVAL '2 days', FALSE),

-- Batch #2: Mozzarella (Fresh Batch expiring in 14 days -> Depleted SECOND by FIFO)
(1, 1, 'BATCH-MOZZ-2026-B2', 10.00, 10.00, CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_DATE + INTERVAL '14 days', FALSE),

-- Batch #3: Russet Potatoes
(2, 2, 'BATCH-POTA-2026-01', 50.00, 42.50, CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_DATE + INTERVAL '20 days', FALSE),

-- Batch #4: Artisan Beef Patties
(3, 3, 'BATCH-BEEF-2026-01', 15.00, 12.00, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_DATE + INTERVAL '12 days', FALSE),

-- Batch #5: Brioche Buns
(4, 4, 'BATCH-BUNS-2026-01', 100.00, 85.00, CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_DATE + INTERVAL '5 days', FALSE),

-- Batch #6: Smoked Gouda
(6, NULL, 'BATCH-GOUD-2026-01', 8.00, 6.50, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_DATE + INTERVAL '18 days', FALSE),

-- Batch #7: Tomato Sauce
(5, NULL, 'BATCH-TOMA-2026-01', 25.00, 22.00, CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_DATE + INTERVAL '30 days', FALSE),

-- Batch #99: INTENTIONALLY EXPIRED BATCH FOR AUTOMATED TRIGGER DEMONSTRATION!
-- Received 10 days ago, expired YESTERDAY. Stock: 4.00L.
-- Calling sweep_and_quarantine_expired_batches() will catch this, zero the stock, 
-- and auto-insert a write-off row into waste_logs!
(7, 5, 'BATCH-CREAM-EXPIRED-99', 4.00, 4.00, CURRENT_TIMESTAMP - INTERVAL '10 days', CURRENT_DATE - INTERVAL '1 day', FALSE);

-- ----------------------------------------------------------------------------
-- STEP 7: MENU ITEMS (Synchronized with DoorDash Front-End App in INR)
-- ----------------------------------------------------------------------------
INSERT INTO menu_items (
    restaurant_id, item_name, item_category, description, price, 
    preparation_time_mins, is_available
) VALUES
(1, 'Cheesy Street Fries', 'Snacks', 'Crispy golden fries smothered in melty aged cheese blend', 180.00, 10, TRUE),
(1, 'Smoked Brioche Burger', 'Burgers', 'Juicy double-sear artisan beef patty with smoked gouda & caramelized shallots', 350.00, 15, TRUE),
(1, 'Margherita Pizza', 'Pizza', 'Woodfired sourdough pizza with San Marzano tomato sauce and fresh mozzarella', 299.00, 18, TRUE),
(2, 'Chole Bhature Executive Platter', 'North Indian', 'Spiced Punjabi chickpeas served with two golden bhature and pickle', 150.00, 12, TRUE),
(3, 'Double Smash Cheeseburger', 'Burgers', 'Two seared beef patties with American cheese and house relish', 260.00, 12, TRUE);

-- ----------------------------------------------------------------------------
-- STEP 8: RECIPE BOM (Bill of Materials linking Dishes to Inventory Ingredients)
-- ----------------------------------------------------------------------------
INSERT INTO recipe_bom (
    item_id, ingredient_id, quantity_required, unit_of_measure, is_critical
) VALUES
-- Cheesy Street Fries (Item 1): 0.35 kg Potatoes + 0.15 kg Mozzarella
(1, 2, 0.350, 'kg', TRUE),
(1, 1, 0.150, 'kg', TRUE),

-- Smoked Brioche Burger (Item 2): 0.22 kg Beef + 0.08 kg Gouda + 1 Bun
(2, 3, 0.220, 'kg', TRUE),
(2, 6, 0.080, 'kg', TRUE),
(2, 4, 1.000, 'units', TRUE),

-- Margherita Pizza (Item 3): 0.20 kg Mozzarella + 0.15 kg Tomato Sauce
(3, 1, 0.200, 'kg', TRUE),
(3, 5, 0.150, 'kg', TRUE);

-- ----------------------------------------------------------------------------
-- STEP 9: CUSTOMERS (JIIT Noida Campus Geodesic Coordinates)
-- ----------------------------------------------------------------------------
INSERT INTO customers (
    first_name, last_name, email, phone_number, delivery_address, city, default_location
) VALUES
('Divyansh', 'Agarwal', 'divyansh.agarwal@jiit.ac.in', '+91-9876543210', 
 'Boys Hostel 1, JIIT Sector 62 Campus, A-10', 'Noida', 
 ST_SetSRID(ST_MakePoint(77.3698, 28.6297), 4326)),

('Abhishek', 'Kumar', 'abhishek.k@jiit.ac.in', '+91-9811223344', 
 'Block B Faculty Residence, Sector 62', 'Noida', 
 ST_SetSRID(ST_MakePoint(77.3680, 28.6285), 4326)),

('Arjun', 'Verma', 'arjun.verma@jiit.ac.in', '+91-9955443322', 
 'Jaypee Wish Town, Sector 128 Campus', 'Noida', 
 ST_SetSRID(ST_MakePoint(77.3520, 28.5140), 4326));

-- ----------------------------------------------------------------------------
-- STEP 10: DASHERS (Couriers with Spatial Coordinates near Sector 62 Roundabout)
-- ----------------------------------------------------------------------------
INSERT INTO dashers (
    first_name, last_name, phone_number, vehicle_type, current_location, 
    is_active, is_available, reliability_rating
) VALUES
-- Dasher 1 ("Raju Kumar"): ONLY ~180 meters from DoorDash Kitchen #1! 
-- PostGIS will select Raju because ST_DWithin = TRUE and distance is minimum.
('Raju', 'Kumar', '+91-9810111222', 'MOTORCYCLE', 
 ST_SetSRID(ST_MakePoint(77.3685, 28.6288), 4326), TRUE, TRUE, 4.92),

-- Dasher 2 ("Amit Singh"): Stationed in Sector 63 (~1.5 km away). Active but farther.
('Amit', 'Singh', '+91-9810333444', 'SCOOTER', 
 ST_SetSRID(ST_MakePoint(77.3810, 28.6305), 4326), TRUE, TRUE, 4.85),

-- Dasher 3 ("Vikas Yadav"): Stationed nearby but OFF DUTY (is_available = FALSE).
-- Engine must ignore him even if closer!
('Vikas', 'Yadav', '+91-9810555666', 'CAR', 
 ST_SetSRID(ST_MakePoint(77.3665, 28.6275), 4326), TRUE, FALSE, 4.70);

-- ----------------------------------------------------------------------------
-- STEP 11: HISTORICAL DELIVERED ORDERS & 3-WAY FINANCIAL SETTLEMENTS (INR)
-- ----------------------------------------------------------------------------
-- Historical Order #1: Delivered earlier today to student Divyansh
INSERT INTO orders (
    customer_id, restaurant_id, dasher_id, order_status, 
    delivery_destination, subtotal, delivery_fee, dasher_tip, total_amount, placed_at, delivered_at
) VALUES
(1, 1, 1, 'DELIVERED', 
 ST_SetSRID(ST_MakePoint(77.3698, 28.6297), 4326), 
 360.00, 40.00, 20.00, 420.00, CURRENT_TIMESTAMP - INTERVAL '3 hours', CURRENT_TIMESTAMP - INTERVAL '2 hours 30 mins');

INSERT INTO order_items (order_id, item_id, quantity, unit_price, subtotal)
VALUES (1, 1, 2, 180.00, 360.00); -- 2x Cheesy Street Fries

-- Penny-perfect ledger check: 288.00 (restaurant 80%) + 72.00 (platform 20%) + 60.00 (dasher fee+tip) = 420.00
INSERT INTO payments (
    order_id, payment_method, payment_status, gross_amount, 
    restaurant_cut, platform_fee, dasher_payout, transaction_reference, settled_at
) VALUES
(1, 'UPI', 'SETTLED', 420.00, 288.00, 72.00, 60.00, 'TXN-UPI-984210', CURRENT_TIMESTAMP - INTERVAL '2 hours 30 mins');

-- Historical Order #2: Delivered to student Abhishek
INSERT INTO orders (
    customer_id, restaurant_id, dasher_id, order_status, 
    delivery_destination, subtotal, delivery_fee, dasher_tip, total_amount, placed_at, delivered_at
) VALUES
(2, 1, 2, 'DELIVERED', 
 ST_SetSRID(ST_MakePoint(77.3680, 28.6285), 4326), 
 350.00, 40.00, 30.00, 420.00, CURRENT_TIMESTAMP - INTERVAL '5 hours', CURRENT_TIMESTAMP - INTERVAL '4 hours 30 mins');

INSERT INTO order_items (order_id, item_id, quantity, unit_price, subtotal)
VALUES (2, 2, 1, 350.00, 350.00); -- 1x Smoked Brioche Burger

-- Penny-perfect ledger check: 280.00 (restaurant 80%) + 70.00 (platform 20%) + 70.00 (dasher fee+tip) = 420.00
INSERT INTO payments (
    order_id, payment_method, payment_status, gross_amount, 
    restaurant_cut, platform_fee, dasher_payout, transaction_reference, settled_at
) VALUES
(2, 'CREDIT_CARD', 'SETTLED', 420.00, 280.00, 70.00, 70.00, 'TXN-CC-192841', CURRENT_TIMESTAMP - INTERVAL '4 hours 30 mins');

COMMIT;
