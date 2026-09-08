CREATE TYPE user_role AS ENUM ('client', 'admin');
CREATE TYPE user_status AS ENUM ('active', 'blocked');
CREATE TYPE category_name AS ENUM (
    'cpu', 'gpu', 'motherboard', 'ram', 'storage', 'psu', 'case', 'cooling'
);
CREATE TYPE build_mode AS ENUM ('auto', 'manual');

CREATE TABLE users (
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
    CONSTRAINT chk_admin_not_blocked CHECK (NOT (role = 'admin' AND status = 'blocked'))
);

CREATE TABLE categories (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name category_name NOT NULL UNIQUE,
    spec_template JSONB NOT NULL DEFAULT '[]'::jsonb 
);

CREATE TABLE components (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    name VARCHAR(255) NOT NULL,
    manufacturer VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    specs JSONB NOT NULL DEFAULT '{}'::jsonb,
    price NUMERIC(10, 2) NOT NULL,
    image_url VARCHAR(500),
    rating NUMERIC(3, 2) DEFAULT 0.00, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_min_price CHECK (price >= 100)
);

CREATE TABLE compatibility_rules (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_1_id BIGINT NOT NULL REFERENCES categories(id),
    category_2_id BIGINT NOT NULL REFERENCES categories(id),
    matching_param_name VARCHAR(50) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_diff_categories CHECK (category_1_id != category_2_id)
);
CREATE TABLE builds (
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
CREATE TABLE build_components (
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    component_id BIGINT NOT NULL REFERENCES components(id) ON DELETE RESTRICT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (build_id, component_id)
);
CREATE TABLE publications (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment TEXT,
    published_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_build_publication UNIQUE (build_id) 
);

CREATE TABLE favorites (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_user_favorite UNIQUE (user_id, build_id)
);

CREATE TABLE likes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_user_like UNIQUE (user_id, build_id)
);

CREATE TABLE comments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    build_id BIGINT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    is_approved BOOLEAN NOT NULL DEFAULT FALSE, -- Для модерации админом
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE reviews (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    component_id BIGINT NOT NULL REFERENCES components(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    text TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_user_component_review UNIQUE (user_id, component_id)
);

CREATE TABLE audit_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL, 
    entity_type VARCHAR(50),    
    entity_id BIGINT,
    details JSONB,              
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_components_category ON components(category_id);
CREATE INDEX idx_components_specs ON components USING GIN (specs);
CREATE INDEX idx_components_price ON components(price);
CREATE INDEX idx_builds_user ON builds(user_id);
CREATE INDEX idx_builds_public ON builds(is_public) WHERE is_public = TRUE;
CREATE INDEX idx_builds_complete ON builds(is_complete) WHERE is_complete = TRUE;
CREATE INDEX idx_likes_build ON likes(build_id);
CREATE INDEX idx_favorites_user ON favorites(user_id);
CREATE INDEX idx_publications_user ON publications(user_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);