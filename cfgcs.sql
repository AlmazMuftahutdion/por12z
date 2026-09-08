CREATE TYPE user_role AS ENUM ('client', 'admin');
CREATE TYPE user_status AS ENUM ('active', 'blocked');
CREATE TYPE category_name AS ENUM (
    'cpu', 'gpu', 'motherboard', 'ram', 'storage', 'psu', 'case', 'cooling'
);
CREATE TYPE build_mode AS ENUM ('auto', 'manual');

CREATE TABLE IF NOT EXISTS users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'client',
    status user_status NOT NULL DEFAULT 'active',
    avatar_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_admin_not_blocked CHECK (NOT (role = 'admin' AND status = 'blocked'))
);

CREATE TABLE IF NOT EXISTS categories (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name category_name NOT NULL UNIQUE,
    spec_template JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_required BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS components (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    name VARCHAR(255) NOT NULL,
    manufacturer VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    specs JSONB NOT NULL DEFAULT '{}'::jsonb,
    price NUMERIC(10, 2) NOT NULL,
    image_url VARCHAR(500),
    rating NUMERIC(3, 2) DEFAULT 0.00,
    stock BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_min_price CHECK (price >= 100)
);

CREATE TABLE IF NOT EXISTS compatibility_rules (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_1_id BIGINT NOT NULL REFERENCES categories(id),
    category_2_id BIGINT NOT NULL REFERENCES categories(id),
    param_1_name VARCHAR(50) NOT NULL,
    param_2_name VARCHAR(50) NOT NULL,
    operator VARCHAR(10) NOT NULL DEFAULT '=',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_diff_categories CHECK (category_1_id != category_2_id)
);

CREATE TABLE IF NOT EXISTS builds (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    total_price NUMERIC(10, 2) DEFAULT 0.00,
    is_compatible BOOLEAN NOT NULL DEFAULT TRUE,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    creation_mode build_mode NOT NULL DEFAULT 'manual',
    cpu_gpu_balance NUMERIC(5, 2),
    likes_count INT NOT NULL DEFAULT 0,
    is_complete BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS build_components (
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    component_id BIGINT NOT NULL REFERENCES components(id) ON DELETE RESTRICT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (build_id, component_id)
);

CREATE TABLE IF NOT EXISTS publications (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment TEXT,
    published_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_build_publication UNIQUE (build_id)
);

CREATE TABLE IF NOT EXISTS favorites (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_favorite UNIQUE (user_id, build_id)
);

CREATE TABLE IF NOT EXISTS likes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_like UNIQUE (user_id, build_id)
);

CREATE TABLE IF NOT EXISTS comments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reviews (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    component_id BIGINT NOT NULL REFERENCES components(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    text TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_component_review UNIQUE (user_id, component_id)
);

CREATE TABLE IF NOT EXISTS news (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    author_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id BIGINT,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_components_updated BEFORE UPDATE ON components
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_builds_updated BEFORE UPDATE ON builds
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_news_updated BEFORE UPDATE ON news
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION calculate_build_price()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE builds
    SET total_price = (
        SELECT COALESCE(SUM(c.price), 0)
        FROM build_components bc
        JOIN components c ON bc.component_id = c.id
        WHERE bc.build_id = NEW.build_id
    )
    WHERE id = NEW.build_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_build_price
    AFTER INSERT OR DELETE ON build_components
    FOR EACH ROW EXECUTE FUNCTION calculate_build_price();

CREATE OR REPLACE FUNCTION check_build_completeness()
RETURNS TRIGGER AS $$
DECLARE
    required_count INT;
    actual_count INT;
BEGIN
    SELECT COUNT(DISTINCT cat.id)
    INTO required_count
    FROM categories cat
    WHERE cat.is_required = TRUE;
    
    SELECT COUNT(DISTINCT c.category_id)
    INTO actual_count
    FROM build_components bc
    JOIN components c ON bc.component_id = c.id
    WHERE bc.build_id = NEW.build_id
    AND c.category_id IN (
        SELECT id FROM categories WHERE is_required = TRUE
    );
    
    UPDATE builds
    SET is_complete = (actual_count >= required_count)
    WHERE id = NEW.build_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_build_completeness
    AFTER INSERT OR DELETE ON build_components
    FOR EACH ROW EXECUTE FUNCTION check_build_completeness();

CREATE OR REPLACE FUNCTION update_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE builds SET likes_count = likes_count + 1 WHERE id = NEW.build_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE builds SET likes_count = likes_count - 1 WHERE id = OLD.build_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_likes_count
    AFTER INSERT OR DELETE ON likes
    FOR EACH ROW EXECUTE FUNCTION update_likes_count();

CREATE OR REPLACE FUNCTION check_component_compatibility()
RETURNS TRIGGER AS $$
DECLARE
    is_compatible BOOLEAN := TRUE;
    conflict_msg TEXT := '';
BEGIN
    IF (SELECT COUNT(*) FROM build_components bc
        JOIN components c ON bc.component_id = c.id
        WHERE bc.build_id = NEW.build_id
        AND c.category_id = (SELECT id FROM categories WHERE name = 'cpu')) > 1 THEN
        is_compatible := FALSE;
        conflict_msg := 'В сборке не может быть два процессора';
    END IF;
    
    UPDATE builds
    SET is_compatible = is_compatible
    WHERE id = NEW.build_id;
    
    IF NOT is_compatible THEN
        RAISE EXCEPTION '%', conflict_msg;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_component_compatibility
    BEFORE INSERT ON build_components
    FOR EACH ROW EXECUTE FUNCTION check_component_compatibility();

CREATE OR REPLACE FUNCTION check_before_publish()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT (SELECT is_complete FROM builds WHERE id = NEW.build_id) THEN
        RAISE EXCEPTION 'Нельзя опубликовать неполную сборку. Добавьте все обязательные компоненты.';
    END IF;
    
    IF NOT (SELECT is_compatible FROM builds WHERE id = NEW.build_id) THEN
        RAISE EXCEPTION 'Нельзя опубликовать несовместимую сборку.';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_before_publish
    BEFORE INSERT ON publications
    FOR EACH ROW EXECUTE FUNCTION check_before_publish();

CREATE INDEX IF NOT EXISTS idx_components_category ON components(category_id);
CREATE INDEX IF NOT EXISTS idx_components_specs ON components USING GIN (specs);
CREATE INDEX IF NOT EXISTS idx_components_price ON components(price);
CREATE INDEX IF NOT EXISTS idx_components_manufacturer ON components(manufacturer);
CREATE INDEX IF NOT EXISTS idx_builds_user ON builds(user_id);
CREATE INDEX IF NOT EXISTS idx_builds_public ON builds(is_public) WHERE is_public = TRUE;
CREATE INDEX IF NOT EXISTS idx_builds_complete ON builds(is_complete) WHERE is_complete = TRUE;
CREATE INDEX IF NOT EXISTS idx_builds_compatible ON builds(is_compatible) WHERE is_compatible = TRUE;
CREATE INDEX IF NOT EXISTS idx_likes_build ON likes(build_id);
CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_publications_user ON publications(user_id);
CREATE INDEX IF NOT EXISTS idx_publications_visible ON publications(is_visible) WHERE is_visible = TRUE;
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_reviews_component ON reviews(component_id);
CREATE INDEX IF NOT EXISTS idx_comments_build ON comments(build_id);

INSERT INTO categories (name, spec_template, is_required) VALUES
    ('cpu', '["socket", "cores", "threads", "base_clock", "boost_clock", "tdp", "platform"]'::jsonb, TRUE),
    ('gpu', '["chipset", "memory_size", "memory_type", "tdp", "length", "interface"]'::jsonb, TRUE),
    ('motherboard', '["socket", "chipset", "form_factor", "ram_type", "max_ram", "ram_slots"]'::jsonb, TRUE),
    ('ram', '["type", "size", "frequency", "timing"]'::jsonb, TRUE),
    ('storage', '["type", "capacity", "interface", "form_factor"]'::jsonb, TRUE),
    ('psu', '["wattage", "efficiency", "modular"]'::jsonb, TRUE),
    ('case', '["form_factor", "max_gpu_length", "max_cooler_height"]'::jsonb, TRUE),
    ('cooling', '["type", "socket_support", "tdp_support", "height"]'::jsonb, FALSE);

INSERT INTO compatibility_rules (category_1_id, category_2_id, param_1_name, param_2_name, operator) VALUES
    ((SELECT id FROM categories WHERE name = 'cpu'), 
     (SELECT id FROM categories WHERE name = 'motherboard'), 
     'socket', 'socket', '='),
    ((SELECT id FROM categories WHERE name = 'motherboard'), 
     (SELECT id FROM categories WHERE name = 'ram'), 
     'ram_type', 'type', '='),
    ((SELECT id FROM categories WHERE name = 'case'), 
     (SELECT id FROM categories WHERE name = 'motherboard'), 
     'form_factor', 'form_factor', 'IN'),
    ((SELECT id FROM categories WHERE name = 'case'), 
     (SELECT id FROM categories WHERE name = 'gpu'), 
     'max_gpu_length', 'length', '>='),
    ((SELECT id FROM categories WHERE name = 'psu'), 
     (SELECT id FROM categories WHERE name = 'cpu'), 
     'wattage', 'tdp', '>='),
    ((SELECT id FROM categories WHERE name = 'cooling'), 
     (SELECT id FROM categories WHERE name = 'cpu'), 
     'socket_support', 'socket', 'IN');

CREATE OR REPLACE VIEW v_build_details AS
SELECT 
    b.id AS build_id,
    b.name AS build_name,
    b.user_id,
    u.first_name || ' ' || u.last_name AS author_name,
    b.total_price,
    b.is_compatible,
    b.is_public,
    b.creation_mode,
    b.cpu_gpu_balance,
    b.likes_count,
    b.is_complete,
    b.created_at,
    b.updated_at,
    COUNT(bc.component_id) AS components_count,
    array_agg(c.name ORDER BY cat.name) AS component_names
FROM builds b
JOIN users u ON b.user_id = u.id
LEFT JOIN build_components bc ON b.id = bc.build_id
LEFT JOIN components c ON bc.component_id = c.id
LEFT JOIN categories cat ON c.category_id = cat.id
GROUP BY b.id, u.first_name, u.last_name;

CREATE OR REPLACE VIEW v_components_full AS
SELECT 
    c.id,
    c.name,
    c.manufacturer,
    c.model,
    c.price,
    c.rating,
    c.stock,
    c.image_url,
    cat.name AS category_name,
    c.specs,
    c.created_at,
    c.updated_at
FROM components c
JOIN categories cat ON c.category_id = cat.id;

CREATE OR REPLACE VIEW v_public_builds AS
SELECT 
    b.id,
    b.name,
    b.total_price,
    b.likes_count,
    b.cpu_gpu_balance,
    b.created_at,
    u.first_name || ' ' || u.last_name AS author_name,
    p.comment,
    p.published_at,
    COUNT(bc.component_id) AS components_count
FROM builds b
JOIN users u ON b.user_id = u.id
JOIN publications p ON b.id = p.build_id
LEFT JOIN build_components bc ON b.id = bc.build_id
WHERE b.is_public = TRUE 
  AND p.is_visible = TRUE
GROUP BY b.id, u.first_name, u.last_name, p.comment, p.published_at;

CREATE OR REPLACE FUNCTION prevent_delete_published_build()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM publications 
        WHERE build_id = OLD.id AND is_visible = TRUE
    ) THEN
        RAISE EXCEPTION 'Нельзя удалить опубликованную сборку. Сначала скройте её из галереи.';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_delete_published
    BEFORE DELETE ON builds
    FOR EACH ROW EXECUTE FUNCTION prevent_delete_published_build();