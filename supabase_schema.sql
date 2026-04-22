-- ============================================================
-- CarbonLit — Complete Supabase Database Schema
-- ============================================================
-- Run this ENTIRE script in the Supabase SQL Editor.
-- It creates all tables, indexes, RLS policies, and views
-- needed for the full CarbonLit app (admin + student).
--
-- Tables:
--   1. profiles           (already exists — this adds missing columns)
--   2. buildings           (normalized building/facility registry)
--   3. emission_factors    (yearly emission conversion factors)
--   4. emission_records    (admin: campus energy data)
--   5. transport_records   (student: transportation footprint)
--   6. gadget_records      (student: gadget/device footprint)
--   7. accommodation_records (student: accommodation footprint)
--   8. audit_log           (track all changes)
--   9. Views for dashboard (real-time analytics)
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. PROFILES — Add missing columns to existing table
-- ────────────────────────────────────────────────────────────
-- Your profiles table already exists. These ALTERs add any
-- columns that might be missing. Safe to run multiple times.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS address      TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS student_id   TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country      TEXT DEFAULT 'MY';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url   TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_active    BOOLEAN DEFAULT TRUE;

-- Index for role-based queries (admin dashboard stats)
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);


-- ────────────────────────────────────────────────────────────
-- 2. BUILDINGS — Normalized building/facility registry
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS buildings (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name        TEXT NOT NULL,
  category    TEXT NOT NULL CHECK (category IN (
                'Academic', 'Mosque', 'Gym', 'Laundry', 'Villages', 'Pool'
              )),
  area_sqm    DOUBLE PRECISION,            -- floor area for intensity metrics
  occupancy   INTEGER,                      -- number of occupants
  meter_id    TEXT,                          -- utility meter reference
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(name, category)
);

-- Seed buildings from your category_item.dart
INSERT INTO buildings (name, category) VALUES
  -- Academic
  ('Block A', 'Academic'), ('Block B', 'Academic'), ('Block C', 'Academic'),
  ('Block D', 'Academic'), ('Block E', 'Academic'), ('Block F', 'Academic'),
  ('Cetal', 'Academic'),   ('Block I', 'Academic'), ('Block J', 'Academic'),
  ('Block K', 'Academic'), ('Block L', 'Academic'), ('Block M', 'Academic'),
  ('Block N', 'Academic'), ('Block O', 'Academic'), ('Block P', 'Academic'),
  ('Block Q', 'Academic'),
  -- Mosque
  ('An-Nur Mosque', 'Mosque'), ('Al-Fatih Mosque', 'Mosque'), ('Al-Khawarizmi Mosque', 'Mosque'),
  -- Gym
  ('Main Gym', 'Gym'), ('Sports Complex', 'Gym'),
  -- Laundry
  ('Cetal', 'Laundry'), ('Dobi Express', 'Laundry'), ('Clean Hub', 'Laundry'),
  -- Villages
  ('Village 1', 'Villages'), ('Village 2', 'Villages'), ('Village 3', 'Villages'),
  ('Village 4', 'Villages'), ('Village 5', 'Villages'), ('Village 6', 'Villages'),
  -- Pool
  ('Olympic Pool', 'Pool'), ('Training Pool', 'Pool')
ON CONFLICT (name, category) DO NOTHING;


-- ────────────────────────────────────────────────────────────
-- 3. EMISSION FACTORS — Yearly conversion factors
-- ────────────────────────────────────────────────────────────
-- Malaysia average grid emission factor ≈ 0.578 kg CO₂/kWh (2024)
-- Source: Energy Commission Malaysia

CREATE TABLE IF NOT EXISTS emission_factors (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fuel_type       TEXT NOT NULL DEFAULT 'grid_electricity',
  factor_value    DOUBLE PRECISION NOT NULL,  -- kg CO₂e per kWh
  unit            TEXT NOT NULL DEFAULT 'kg_co2e_per_kwh',
  effective_year  INTEGER NOT NULL,
  country         TEXT DEFAULT 'MY',
  source          TEXT,                        -- reference / citation
  created_at      TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(fuel_type, effective_year, country)
);

-- Seed with Malaysia grid electricity factors
INSERT INTO emission_factors (fuel_type, factor_value, effective_year, source) VALUES
  ('grid_electricity', 0.585, 2022, 'Energy Commission Malaysia'),
  ('grid_electricity', 0.580, 2023, 'Energy Commission Malaysia'),
  ('grid_electricity', 0.578, 2024, 'Energy Commission Malaysia'),
  ('grid_electricity', 0.575, 2025, 'Energy Commission Malaysia (est.)')
ON CONFLICT (fuel_type, effective_year, country) DO NOTHING;

-- Fuel types for transport calculator
INSERT INTO emission_factors (fuel_type, factor_value, unit, effective_year, source) VALUES
  ('petrol_ron95', 2.31, 'kg_co2e_per_liter', 2024, 'IPCC Guidelines'),
  ('petrol_ron97', 2.31, 'kg_co2e_per_liter', 2024, 'IPCC Guidelines'),
  ('diesel',       2.68, 'kg_co2e_per_liter', 2024, 'IPCC Guidelines'),
  ('ev',           0.0,  'kg_co2e_per_km',    2024, 'Zero tailpipe')
ON CONFLICT (fuel_type, effective_year, country) DO NOTHING;


-- ────────────────────────────────────────────────────────────
-- 4. EMISSION RECORDS — Admin campus energy data
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS emission_records (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  building_name    TEXT NOT NULL,
  category         TEXT NOT NULL CHECK (category IN (
                     'Academic', 'Mosque', 'Gym', 'Laundry', 'Villages', 'Pool'
                   )),
  month            TEXT NOT NULL,               -- 'January', 'February', etc.
  year             INTEGER NOT NULL,            -- 2024, 2025, etc.
  energy_consumed  DOUBLE PRECISION NOT NULL,   -- kWh
  emission_value   DOUBLE PRECISION,            -- kg CO₂e (calculated)
  energy_rate      DOUBLE PRECISION,            -- RM per kWh at time of entry
  cost             DOUBLE PRECISION,            -- energy_consumed × energy_rate
  notes            TEXT,
  recorded_by      UUID REFERENCES auth.users(id),  -- which admin entered this
  building_id      UUID REFERENCES buildings(id),    -- FK to buildings table
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate entries for same building/month/year
  UNIQUE(building_name, category, month, year)
);

CREATE INDEX IF NOT EXISTS idx_emission_category   ON emission_records(category);
CREATE INDEX IF NOT EXISTS idx_emission_month_year ON emission_records(month, year);
CREATE INDEX IF NOT EXISTS idx_emission_building   ON emission_records(building_name);
CREATE INDEX IF NOT EXISTS idx_emission_recorded   ON emission_records(recorded_by);


-- ────────────────────────────────────────────────────────────
-- 5. TRANSPORT RECORDS — Student transportation footprint
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transport_records (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vehicle_type     TEXT NOT NULL,               -- Car, Bus, Motorcycle, etc.
  model_vehicle    TEXT,                         -- user-entered model
  fuel_type        TEXT,                         -- Diesel, Petrol (RON95), etc.
  engine_size      TEXT,                         -- Engine size category (Small, Medium, Large, etc.)
  origin_lat       DOUBLE PRECISION,
  origin_lng       DOUBLE PRECISION,
  origin_place     TEXT,                         -- reverse-geocoded place name
  origin_address   TEXT,
  distance_km      DOUBLE PRECISION,
  daily_emission   DOUBLE PRECISION,            -- kg CO₂e/day
  trees_to_offset  INTEGER,                     -- trees needed per year
  recorded_date    DATE DEFAULT CURRENT_DATE,
  created_at       TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent exact duplicate trip on same day
  UNIQUE(user_id, vehicle_type, distance_km, recorded_date)
);

CREATE INDEX IF NOT EXISTS idx_transport_user ON transport_records(user_id);
CREATE INDEX IF NOT EXISTS idx_transport_date ON transport_records(recorded_date);


-- ────────────────────────────────────────────────────────────
-- 6. GADGET RECORDS — Student gadget/device footprint
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gadget_records (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  gadget_type         TEXT,                      -- category of gadget
  device_name         TEXT NOT NULL,
  usage_hours_per_day DOUBLE PRECISION NOT NULL,
  daily_emission      DOUBLE PRECISION,          -- kg CO₂e/day
  trees_to_offset     INTEGER,
  recorded_date       DATE DEFAULT CURRENT_DATE,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gadget_user ON gadget_records(user_id);


-- ────────────────────────────────────────────────────────────
-- 7. ACCOMMODATION RECORDS — Student accommodation footprint
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS accommodation_records (
  id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  accommodation_type    TEXT,                    -- Hotel, Apartment, House
  accommodation_name    TEXT NOT NULL,
  usage_hours_per_day   DOUBLE PRECISION NOT NULL,
  daily_emission        DOUBLE PRECISION,        -- kg CO₂e/day
  trees_to_offset       INTEGER,
  recorded_date         DATE DEFAULT CURRENT_DATE,
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_accommodation_user ON accommodation_records(user_id);


-- ────────────────────────────────────────────────────────────
-- 8. AUDIT LOG — Track all data changes for compliance
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  table_name  TEXT NOT NULL,
  record_id   TEXT NOT NULL,
  action      TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_data    JSONB,
  new_data    JSONB,
  performed_by UUID REFERENCES auth.users(id),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_table  ON audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_date   ON audit_log(created_at);


-- ────────────────────────────────────────────────────────────
-- 9. DASHBOARD VIEWS — Real-time analytics
-- ────────────────────────────────────────────────────────────

-- 9a. Total emission per category per month
CREATE OR REPLACE VIEW v_emission_by_category AS
SELECT
  category,
  month,
  year,
  COUNT(*)                     AS record_count,
  SUM(energy_consumed)         AS total_energy_kwh,
  SUM(emission_value)          AS total_emission_kg,
  ROUND(AVG(energy_consumed)::NUMERIC, 2) AS avg_energy_kwh
FROM emission_records
GROUP BY category, month, year
ORDER BY year DESC, month;

-- 9b. Total emission per building
CREATE OR REPLACE VIEW v_emission_by_building AS
SELECT
  building_name,
  category,
  COUNT(*)                     AS records,
  SUM(energy_consumed)         AS total_energy_kwh,
  SUM(emission_value)          AS total_emission_kg,
  MIN(year)                    AS first_year,
  MAX(year)                    AS latest_year
FROM emission_records
GROUP BY building_name, category
ORDER BY total_energy_kwh DESC;

-- 9c. Monthly trend (all categories combined)
CREATE OR REPLACE VIEW v_monthly_trend AS
SELECT
  year,
  month,
  SUM(energy_consumed)  AS total_energy_kwh,
  SUM(emission_value)   AS total_emission_kg,
  COUNT(DISTINCT building_name) AS buildings_reported
FROM emission_records
GROUP BY year, month
ORDER BY year, 
  CASE month
    WHEN 'January'   THEN 1  WHEN 'February'  THEN 2
    WHEN 'March'     THEN 3  WHEN 'April'     THEN 4
    WHEN 'May'       THEN 5  WHEN 'June'      THEN 6
    WHEN 'July'      THEN 7  WHEN 'August'    THEN 8
    WHEN 'September' THEN 9  WHEN 'October'   THEN 10
    WHEN 'November'  THEN 11 WHEN 'December'  THEN 12
  END;

-- 9d. Student personal footprint summary
CREATE OR REPLACE VIEW v_student_footprint AS
SELECT
  u.id AS user_id,
  p.first_name,
  p.last_name,
  COALESCE(t.transport_emission, 0)     AS transport_emission,
  COALESCE(g.gadget_emission, 0)        AS gadget_emission,
  COALESCE(a.accommodation_emission, 0) AS accommodation_emission,
  COALESCE(t.transport_emission, 0)
    + COALESCE(g.gadget_emission, 0)
    + COALESCE(a.accommodation_emission, 0) AS total_daily_emission,
  COALESCE(t.transport_trees, 0)
    + COALESCE(g.gadget_trees, 0)
    + COALESCE(a.accommodation_trees, 0) AS total_trees_to_offset
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
LEFT JOIN (
  SELECT user_id,
    SUM(daily_emission)  AS transport_emission,
    SUM(trees_to_offset) AS transport_trees
  FROM transport_records GROUP BY user_id
) t ON t.user_id = u.id
LEFT JOIN (
  SELECT user_id,
    SUM(daily_emission)  AS gadget_emission,
    SUM(trees_to_offset) AS gadget_trees
  FROM gadget_records GROUP BY user_id
) g ON g.user_id = u.id
LEFT JOIN (
  SELECT user_id,
    SUM(daily_emission)  AS accommodation_emission,
    SUM(trees_to_offset) AS accommodation_trees
  FROM accommodation_records GROUP BY user_id
) a ON a.user_id = u.id;

-- 9e. Campus-wide summary (for admin dashboard header)
CREATE OR REPLACE VIEW v_campus_summary AS
SELECT
  (SELECT COUNT(*) FROM profiles WHERE role = 'student') AS total_students,
  (SELECT COUNT(*) FROM profiles WHERE role = 'admin')   AS total_admins,
  (SELECT COUNT(*) FROM buildings WHERE is_active = TRUE) AS total_buildings,
  (SELECT COALESCE(SUM(energy_consumed), 0) FROM emission_records)  AS total_energy_kwh,
  (SELECT COALESCE(SUM(emission_value), 0) FROM emission_records)   AS total_emission_kg,
  (SELECT COUNT(DISTINCT building_name) FROM emission_records)      AS buildings_reported;


-- ────────────────────────────────────────────────────────────
-- 10. ROW LEVEL SECURITY (RLS) POLICIES
-- ────────────────────────────────────────────────────────────

-- Enable RLS on all tables
ALTER TABLE profiles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE buildings              ENABLE ROW LEVEL SECURITY;
ALTER TABLE emission_factors       ENABLE ROW LEVEL SECURITY;
ALTER TABLE emission_records       ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_records      ENABLE ROW LEVEL SECURITY;
ALTER TABLE gadget_records         ENABLE ROW LEVEL SECURITY;
ALTER TABLE accommodation_records  ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log              ENABLE ROW LEVEL SECURITY;

-- Profiles: all authenticated users can read (for leaderboard), users can only write their own
CREATE POLICY profiles_read_all   ON profiles FOR SELECT USING (true);
CREATE POLICY profiles_insert_own ON profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY profiles_update_own ON profiles FOR UPDATE USING (id = auth.uid());

-- Buildings: everyone can read, only admins can write
CREATE POLICY buildings_read  ON buildings FOR SELECT USING (true);
CREATE POLICY buildings_write ON buildings FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Emission factors: everyone can read, only admins can write
CREATE POLICY ef_read  ON emission_factors FOR SELECT USING (true);
CREATE POLICY ef_write ON emission_factors FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Emission records: everyone can read (for dashboard), only admins can write
CREATE POLICY er_read  ON emission_records FOR SELECT USING (true);
CREATE POLICY er_insert ON emission_records FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY er_update ON emission_records FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY er_delete ON emission_records FOR DELETE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Transport records: all authenticated users can read (for leaderboard), students own their data for writes
CREATE POLICY tr_select ON transport_records FOR SELECT USING (true);
CREATE POLICY tr_insert ON transport_records FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY tr_update ON transport_records FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY tr_delete ON transport_records FOR DELETE USING (user_id = auth.uid());

-- Gadget records: all authenticated users can read (for leaderboard), students own their data for writes
CREATE POLICY gr_select ON gadget_records FOR SELECT USING (true);
CREATE POLICY gr_insert ON gadget_records FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY gr_update ON gadget_records FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY gr_delete ON gadget_records FOR DELETE USING (user_id = auth.uid());

-- Accommodation records: all authenticated users can read (for leaderboard), students own their data for writes
CREATE POLICY ar_select ON accommodation_records FOR SELECT USING (true);
CREATE POLICY ar_insert ON accommodation_records FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY ar_update ON accommodation_records FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY ar_delete ON accommodation_records FOR DELETE USING (user_id = auth.uid());

-- Audit log: only admins can read, system inserts via trigger
CREATE POLICY al_read ON audit_log FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY al_insert ON audit_log FOR INSERT WITH CHECK (true);


-- ────────────────────────────────────────────────────────────
-- 11. AUTO-UPDATE updated_at TRIGGER
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at column
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY['profiles', 'buildings', 'emission_records'])
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_updated_at ON %I; 
       CREATE TRIGGER trg_updated_at BEFORE UPDATE ON %I 
       FOR EACH ROW EXECUTE FUNCTION update_updated_at();',
      t, t
    );
  END LOOP;
END $$;


-- ────────────────────────────────────────────────────────────
-- 12. AUDIT LOG TRIGGER — Auto-log changes to emission_records
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_audit_emission_records()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_log (table_name, record_id, action, new_data, performed_by)
    VALUES ('emission_records', NEW.id::TEXT, 'INSERT', to_jsonb(NEW), auth.uid());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_log (table_name, record_id, action, old_data, new_data, performed_by)
    VALUES ('emission_records', NEW.id::TEXT, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), auth.uid());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_log (table_name, record_id, action, old_data, performed_by)
    VALUES ('emission_records', OLD.id::TEXT, 'DELETE', to_jsonb(OLD), auth.uid());
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_audit_emission ON emission_records;
CREATE TRIGGER trg_audit_emission
  AFTER INSERT OR UPDATE OR DELETE ON emission_records
  FOR EACH ROW EXECUTE FUNCTION fn_audit_emission_records();


-- ────────────────────────────────────────────────────────────
-- 13. ENABLE REALTIME for dashboard tables
-- ────────────────────────────────────────────────────────────
-- In Supabase, enable Realtime on these tables via Dashboard > Database > Replication
-- or run these (requires superuser / dashboard):
--
-- ALTER PUBLICATION supabase_realtime ADD TABLE emission_records;
-- ALTER PUBLICATION supabase_realtime ADD TABLE transport_records;
-- ALTER PUBLICATION supabase_realtime ADD TABLE gadget_records;
-- ALTER PUBLICATION supabase_realtime ADD TABLE accommodation_records;
-- ALTER PUBLICATION supabase_realtime ADD TABLE profiles;


-- ============================================================
-- DONE! Your database is fully set up for CarbonLit.
-- ============================================================


-- ============================================================
-- MIGRATION: Add wattage columns for proper emission calculation
-- Safe to run multiple times (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS)
-- ============================================================

-- Gadget records: store device wattage for formula: (watts × hours) / 1000 × EF
ALTER TABLE gadget_records ADD COLUMN IF NOT EXISTS wattage DOUBLE PRECISION;

-- Accommodation records: store appliance wattage
ALTER TABLE accommodation_records ADD COLUMN IF NOT EXISTS wattage DOUBLE PRECISION;
