-- =====================================================================
--  БД «Конфигуратор ПК с ИИ» (PostgreSQL 13+, проверено на 16)
--  Создание: createdb pc_configurator && psql -d pc_configurator -f 01_schema.sql
-- =====================================================================
\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS citext;    -- e-mail без учёта регистра
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- bcrypt для fn_register_user / fn_login

-- ---------------------------------------------------------------------
-- Типы
-- ---------------------------------------------------------------------
CREATE TYPE user_role          AS ENUM ('client', 'admin');
CREATE TYPE user_status        AS ENUM ('active', 'blocked');
CREATE TYPE build_mode         AS ENUM ('auto_ai', 'manual');
CREATE TYPE balance_status     AS ENUM ('unknown', 'balanced', 'cpu_bottleneck', 'gpu_bottleneck');
CREATE TYPE publication_status AS ENUM ('published', 'hidden');   -- hidden = скрыта до проверки
CREATE TYPE char_data_type     AS ENUM ('text', 'number');

-- ---------------------------------------------------------------------
-- Служебная функция updated_at
-- ---------------------------------------------------------------------
CREATE FUNCTION trg_set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;

-- =====================================================================
--  КАТАЛОГ КОМПЛЕКТУЮЩИХ
-- =====================================================================

-- Категории комплектующих
CREATE TABLE component_categories (
    id           smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code         varchar(30)  NOT NULL UNIQUE,   -- processors, motherboards, ...
    name         varchar(100) NOT NULL UNIQUE,   -- «Процессор», «Видеокарта», ...
    is_required  boolean      NOT NULL DEFAULT true,  -- обязателен для «полной» сборки
    sort_order   smallint     NOT NULL DEFAULT 0
);

-- Список характеристик категории
CREATE TABLE characteristics (
    id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id  smallint     NOT NULL REFERENCES component_categories(id) ON DELETE CASCADE,
    code         varchar(40)  NOT NULL,          -- socket, tdp_w, ... (используется в проверках совместимости)
    name         varchar(100) NOT NULL,          -- «Сокет», «TDP» ...
    unit         varchar(20),                    -- Вт, ГБ, МГц ...
    data_type    char_data_type NOT NULL DEFAULT 'text',
    is_required  boolean      NOT NULL DEFAULT false,  -- обязательно заполнять админу
    aliases      text[]       NOT NULL DEFAULT '{}',   -- как характеристика называется на источнике (Regard) — для импорта
    sort_order   smallint     NOT NULL DEFAULT 0,
    UNIQUE (category_id, code),
    UNIQUE (id, category_id)                     -- для составного FK
);

-- Комплектующие
CREATE TABLE components (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id   smallint      NOT NULL REFERENCES component_categories(id),
    name          varchar(300)  NOT NULL,        -- полное наименование
    manufacturer  varchar(100)  NOT NULL,
    model         varchar(250)  NOT NULL,
    price         numeric(12,2) NOT NULL,        -- цена в рублях
    is_active     boolean       NOT NULL DEFAULT true,   -- false = снят с производства/скрыт (мягкое удаление)
    source        varchar(30),                   -- 'regard' и т.п.
    external_id   varchar(50),                   -- id товара на источнике
    source_url    text,
    raw_specs     jsonb,                         -- исходные характеристики с источника «как есть»
    created_at    timestamptz   NOT NULL DEFAULT now(),
    updated_at    timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT ck_components_price_min CHECK (price >= 100),   -- ТЗ: нельзя добавить компонент дешевле 100 ₽
    UNIQUE (id, category_id),
    UNIQUE (source, external_id)
);
CREATE INDEX ix_components_category_price ON components (category_id, price) WHERE is_active;
CREATE INDEX ix_components_manufacturer   ON components (manufacturer);
CREATE TRIGGER trg_components_updated BEFORE UPDATE ON components
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

-- Значения характеристик (EAV). Характеристика обязана принадлежать категории компонента.
CREATE TABLE component_characteristic_values (
    component_id       bigint   NOT NULL,
    characteristic_id  integer  NOT NULL,
    category_id        smallint NOT NULL,
    value_text         text     NOT NULL,        -- значение как текст
    value_num          numeric,                  -- числовое значение (для number-характеристик)
    PRIMARY KEY (component_id, characteristic_id),
    FOREIGN KEY (component_id, category_id)      REFERENCES components (id, category_id) ON DELETE CASCADE,
    FOREIGN KEY (characteristic_id, category_id) REFERENCES characteristics (id, category_id) ON DELETE CASCADE
);
CREATE INDEX ix_ccv_characteristic ON component_characteristic_values (characteristic_id, value_num);

-- =====================================================================
--  ПОЛЬЗОВАТЕЛИ
-- =====================================================================
CREATE TABLE users (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    last_name      varchar(60)  NOT NULL,
    first_name     varchar(60)  NOT NULL,
    middle_name    varchar(60),
    email          citext       NOT NULL UNIQUE,
    password_hash  text         NOT NULL,        -- хэш (bcrypt), НЕ пароль
    role           user_role    NOT NULL DEFAULT 'client',
    registered_at  timestamptz  NOT NULL DEFAULT now(),
    status         user_status  NOT NULL DEFAULT 'active',
    avatar_url     text,
    CONSTRAINT ck_users_email CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    -- ТЗ: администратор не может быть заблокирован
    CONSTRAINT ck_users_admin_not_blocked CHECK (role <> 'admin' OR status = 'active')
);

-- =====================================================================
--  СБОРКИ
-- =====================================================================
CREATE TABLE builds (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name              varchar(150)  NOT NULL,
    user_id           bigint        NOT NULL REFERENCES users(id),
    creation_mode     build_mode    NOT NULL DEFAULT 'manual',
    budget            numeric(12,2),                         -- бюджет при автосборке
    created_at        timestamptz   NOT NULL DEFAULT now(),
    updated_at        timestamptz   NOT NULL DEFAULT now(),  -- дата последнего изменения
    total_price       numeric(12,2) NOT NULL DEFAULT 0,      -- считается триггером
    is_complete       boolean       NOT NULL DEFAULT false,  -- выбраны все обязательные категории (триггер)
    is_compatible     boolean       NOT NULL DEFAULT true,   -- совместимость (триггер)
    is_public         boolean       NOT NULL DEFAULT false,  -- ведётся триггерами публикаций
    likes_count       integer       NOT NULL DEFAULT 0,      -- ведётся триггерами лайков
    cpu_gpu_balance   balance_status NOT NULL DEFAULT 'unknown',  -- индикатор баланса CPU/GPU
    cpu_gpu_diff      numeric(6,2),                          -- perf(GPU) − perf(CPU), для UI-индикатора
    share_token       uuid          NOT NULL DEFAULT gen_random_uuid() UNIQUE,  -- уникальная ссылка на сборку
    copied_from_id    bigint        REFERENCES builds(id) ON DELETE SET NULL,   -- «скопирована как основа»
    UNIQUE (id, user_id),
    CONSTRAINT ck_builds_budget CHECK (budget IS NULL OR budget > 0),
    CONSTRAINT ck_builds_auto_budget CHECK (creation_mode = 'manual' OR budget IS NOT NULL),
    CONSTRAINT ck_builds_likes CHECK (likes_count >= 0)
);
CREATE INDEX ix_builds_user      ON builds (user_id, updated_at DESC);
CREATE INDEX ix_builds_public    ON builds (likes_count DESC) WHERE is_public;

-- Состав сборки: по одному компоненту каждой категории
CREATE TABLE build_components (
    build_id      bigint      NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    category_id   smallint    NOT NULL,
    component_id  bigint      NOT NULL,
    added_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (build_id, category_id),
    -- компонент должен быть именно этой категории
    FOREIGN KEY (component_id, category_id) REFERENCES components (id, category_id) ON DELETE RESTRICT
);
CREATE INDEX ix_build_components_component ON build_components (component_id);

-- Публикации в галерее
CREATE TABLE publications (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    build_id      bigint      NOT NULL UNIQUE,
    user_id       bigint      NOT NULL,
    published_at  timestamptz NOT NULL DEFAULT now(),
    author_comment text,
    status        publication_status NOT NULL DEFAULT 'published',
    -- публиковать может только автор сборки
    FOREIGN KEY (build_id, user_id) REFERENCES builds (id, user_id) ON DELETE CASCADE
);
CREATE INDEX ix_publications_date ON publications (published_at DESC);

-- Избранное
CREATE TABLE favorites (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id   bigint      NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    build_id  bigint      NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    added_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, build_id)
);
CREATE INDEX ix_favorites_build ON favorites (build_id);

-- Лайки
CREATE TABLE likes (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id   bigint      NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    build_id  bigint      NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
    added_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, build_id)
);
CREATE INDEX ix_likes_build ON likes (build_id);

-- =====================================================================
--  АДМИНИСТРАТИВНОЕ: журнал событий и новости
-- =====================================================================
CREATE TABLE event_log (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at   timestamptz  NOT NULL DEFAULT now(),
    user_id      bigint       REFERENCES users(id) ON DELETE SET NULL,   -- кто совершил действие
    event_type   varchar(50)  NOT NULL,     -- user_registered, user_blocked, build_published, ...
    entity_type  varchar(30),
    entity_id    bigint,
    details      jsonb
);
CREATE INDEX ix_event_log_created ON event_log (created_at DESC);
CREATE INDEX ix_event_log_type    ON event_log (event_type, created_at DESC);

CREATE TABLE news (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title         varchar(200) NOT NULL,
    body          text         NOT NULL,
    author_id     bigint       REFERENCES users(id) ON DELETE SET NULL,
    published_at  timestamptz  NOT NULL DEFAULT now()
);

-- =====================================================================
--  ФУНКЦИИ ПРОВЕРКИ СОВМЕСТИМОСТИ
--  Правила опираются на коды характеристик (characteristics.code).
--  Если значение характеристики не заполнено — правило пропускается
--  (нельзя проверить → не блокируем).
-- =====================================================================

-- нормализация: нижний регистр, без слова socket, пробелов, дефисов
CREATE FUNCTION fn_norm(p text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_replace(lower(coalesce(p, '')), 'socket|[\s\-_]', '', 'g')
$$;

-- нормализация форм-фактора: Micro-ATX / mATX → matx, Mini-ITX → itx
CREATE FUNCTION fn_norm_ff(p text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN fn_norm(p) ~ '^(micro|m)atx$'  THEN 'matx'
        WHEN fn_norm(p) ~ '^(mini)?itx$'    THEN 'itx'
        WHEN fn_norm(p) ~ '^(e|extended)atx$' THEN 'eatx'
        ELSE fn_norm(p)
    END
$$;

-- входит ли item в список «a, b / c; d»
CREATE FUNCTION fn_list_has(p_list text, p_item text, p_ff boolean DEFAULT false)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
    SELECT EXISTS (
        SELECT 1
        FROM unnest(regexp_split_to_array(p_list, '\s*[,;/]\s*')) AS t(x)
        WHERE CASE WHEN p_ff THEN fn_norm_ff(t.x) = fn_norm_ff(p_item)
                   ELSE fn_norm(t.x) = fn_norm(p_item) END
    )
$$;

CREATE FUNCTION fn_val_text(p_component bigint, p_code text) RETURNS text
LANGUAGE sql STABLE AS $$
    SELECT v.value_text
    FROM component_characteristic_values v
    JOIN characteristics c ON c.id = v.characteristic_id
    WHERE v.component_id = p_component AND c.code = p_code
$$;

CREATE FUNCTION fn_val_num(p_component bigint, p_code text) RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT v.value_num
    FROM component_characteristic_values v
    JOIN characteristics c ON c.id = v.characteristic_id
    WHERE v.component_id = p_component AND c.code = p_code
$$;

-- Список проблем совместимости сборки (пустой набор = всё совместимо)
CREATE FUNCTION fn_build_issues(p_build bigint) RETURNS SETOF text
LANGUAGE plpgsql STABLE AS $$
DECLARE
    cpu bigint; mb bigint; gpu bigint; ram bigint; psu bigint; pcase bigint; cool bigint;
    s1 text; s2 text; t_ram text; t_mb text;
    n1 numeric; n2 numeric; req numeric;
BEGIN
    SELECT max(bc.component_id) FILTER (WHERE cc.code = 'processors'),
           max(bc.component_id) FILTER (WHERE cc.code = 'motherboards'),
           max(bc.component_id) FILTER (WHERE cc.code = 'graphics_cards'),
           max(bc.component_id) FILTER (WHERE cc.code = 'ram'),
           max(bc.component_id) FILTER (WHERE cc.code = 'power_supplies'),
           max(bc.component_id) FILTER (WHERE cc.code = 'cases'),
           max(bc.component_id) FILTER (WHERE cc.code = 'cooling')
      INTO cpu, mb, gpu, ram, psu, pcase, cool
      FROM build_components bc
      JOIN component_categories cc ON cc.id = bc.category_id
     WHERE bc.build_id = p_build;

    -- процессор ↔ материнская плата: сокет
    IF cpu IS NOT NULL AND mb IS NOT NULL THEN
        s1 := fn_val_text(cpu, 'socket'); s2 := fn_val_text(mb, 'socket');
        IF s1 IS NOT NULL AND s2 IS NOT NULL AND NOT fn_list_has(s2, s1) THEN
            RETURN NEXT format('Сокет процессора (%s) не подходит к материнской плате (%s)', s1, s2);
        END IF;
    END IF;

    -- память ↔ материнская плата: тип, число модулей, объём
    IF ram IS NOT NULL AND mb IS NOT NULL THEN
        t_ram := substring(upper(coalesce(fn_val_text(ram, 'memory_type'), '')) FROM 'DDR[0-9]');
        t_mb  := upper(coalesce(fn_val_text(mb, 'memory_type'), ''));
        IF t_ram IS NOT NULL AND t_mb ~ 'DDR[0-9]' AND position(t_ram IN t_mb) = 0 THEN
            RETURN NEXT format('Тип памяти %s не поддерживается материнской платой (%s)', t_ram, t_mb);
        END IF;
        n1 := fn_val_num(ram, 'modules_count'); n2 := fn_val_num(mb, 'memory_slots');
        IF n1 IS NOT NULL AND n2 IS NOT NULL AND n1 > n2 THEN
            RETURN NEXT format('Модулей памяти (%s) больше, чем слотов на плате (%s)', n1, n2);
        END IF;
        n1 := fn_val_num(ram, 'capacity_gb'); n2 := fn_val_num(mb, 'max_memory_gb');
        IF n1 IS NOT NULL AND n2 IS NOT NULL AND n1 > n2 THEN
            RETURN NEXT format('Объём памяти (%s ГБ) превышает максимум платы (%s ГБ)', n1, n2);
        END IF;
    END IF;

    -- материнская плата ↔ корпус: форм-фактор
    IF mb IS NOT NULL AND pcase IS NOT NULL THEN
        s1 := fn_val_text(mb, 'form_factor'); s2 := fn_val_text(pcase, 'form_factors');
        IF s1 IS NOT NULL AND s2 IS NOT NULL AND NOT fn_list_has(s2, s1, true) THEN
            RETURN NEXT format('Форм-фактор платы (%s) не поддерживается корпусом (%s)', s1, s2);
        END IF;
    END IF;

    -- видеокарта ↔ корпус: длина
    IF gpu IS NOT NULL AND pcase IS NOT NULL THEN
        n1 := fn_val_num(gpu, 'length_mm'); n2 := fn_val_num(pcase, 'max_gpu_length_mm');
        IF n1 IS NOT NULL AND n2 IS NOT NULL AND n1 > n2 THEN
            RETURN NEXT format('Видеокарта (%s мм) не помещается в корпус (до %s мм)', n1, n2);
        END IF;
    END IF;

    -- кулер ↔ процессор: сокет и теплоотвод
    IF cool IS NOT NULL AND cpu IS NOT NULL THEN
        s1 := fn_val_text(cpu, 'socket'); s2 := fn_val_text(cool, 'sockets');
        IF s1 IS NOT NULL AND s2 IS NOT NULL AND NOT fn_list_has(s2, s1) THEN
            RETURN NEXT format('Кулер не поддерживает сокет процессора (%s)', s1);
        END IF;
        n1 := fn_val_num(cpu, 'tdp_w'); n2 := fn_val_num(cool, 'tdp_w');
        IF n1 IS NOT NULL AND n2 IS NOT NULL AND n1 > n2 THEN
            RETURN NEXT format('Кулер рассчитан на %s Вт, процессору нужно %s Вт', n2, n1);
        END IF;
    END IF;

    -- блок питания ↔ процессор + видеокарта: мощность
    IF psu IS NOT NULL AND (cpu IS NOT NULL OR gpu IS NOT NULL) THEN
        n2 := fn_val_num(psu, 'power_w');
        req := greatest(
                   coalesce(fn_val_num(gpu, 'recommended_psu_w'), 0),
                   CASE WHEN fn_val_num(cpu, 'tdp_w') IS NULL AND fn_val_num(gpu, 'tdp_w') IS NULL THEN 0
                        ELSE coalesce(fn_val_num(cpu, 'tdp_w'), 0) + coalesce(fn_val_num(gpu, 'tdp_w'), 0) + 150 END);
        IF n2 IS NOT NULL AND req > 0 AND n2 < req THEN
            RETURN NEXT format('Мощности блока питания (%s Вт) недостаточно, нужно не менее %s Вт', n2, req);
        END IF;
    END IF;
END $$;

-- Пересчёт производных полей сборки
CREATE FUNCTION fn_recalc_build(p_build bigint) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_price   numeric(12,2);
    v_missing int;
    v_cpu bigint; v_gpu bigint; v_c numeric; v_g numeric;
    v_diff numeric(6,2); v_bal balance_status;
    v_public boolean; v_complete boolean;
BEGIN
    SELECT is_public INTO v_public FROM builds WHERE id = p_build;
    IF NOT FOUND THEN RETURN; END IF;                   -- сборка удаляется каскадом

    SELECT coalesce(sum(c.price), 0) INTO v_price
      FROM build_components bc JOIN components c ON c.id = bc.component_id
     WHERE bc.build_id = p_build;

    SELECT count(*) INTO v_missing
      FROM component_categories cc
     WHERE cc.is_required
       AND NOT EXISTS (SELECT 1 FROM build_components bc
                        WHERE bc.build_id = p_build AND bc.category_id = cc.id);
    v_complete := (v_missing = 0);

    -- баланс CPU/GPU по характеристике perf_score (шкала 0–100)
    SELECT max(bc.component_id) FILTER (WHERE cc.code = 'processors'),
           max(bc.component_id) FILTER (WHERE cc.code = 'graphics_cards')
      INTO v_cpu, v_gpu
      FROM build_components bc JOIN component_categories cc ON cc.id = bc.category_id
     WHERE bc.build_id = p_build;
    v_c := fn_val_num(v_cpu, 'perf_score');
    v_g := fn_val_num(v_gpu, 'perf_score');
    IF v_c IS NULL OR v_g IS NULL THEN
        v_diff := NULL; v_bal := 'unknown';
    ELSE
        v_diff := v_g - v_c;
        v_bal := CASE WHEN v_diff >  15 THEN 'cpu_bottleneck'   -- GPU заметно мощнее → CPU тормозит
                      WHEN v_diff < -15 THEN 'gpu_bottleneck'
                      ELSE 'balanced' END;
    END IF;

    -- опубликованная сборка не должна становиться неполной
    IF v_public AND NOT v_complete THEN
        RAISE EXCEPTION 'Нельзя удалить обязательный компонент из опубликованной сборки (id=%)', p_build
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE builds
       SET total_price = v_price,
           is_complete = v_complete,
           is_compatible = NOT EXISTS (SELECT 1 FROM fn_build_issues(p_build)),
           cpu_gpu_balance = v_bal,
           cpu_gpu_diff = v_diff,
           updated_at = now()
     WHERE id = p_build;
END $$;

-- =====================================================================
--  ТРИГГЕРЫ
-- =====================================================================

-- Состав сборки: проверка совместимости после КАЖДОГО добавления/замены
-- (ТЗ: и в ручном режиме, и ИИ подбирает только совместимое) + пересчёт
CREATE FUNCTION trg_build_components_check() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_issues text;
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM fn_recalc_build(OLD.build_id);
        RETURN OLD;
    END IF;

    SELECT string_agg(i, '; ') INTO v_issues FROM fn_build_issues(NEW.build_id) AS i;
    IF v_issues IS NOT NULL THEN
        RAISE EXCEPTION 'Несовместимый компонент: %', v_issues USING ERRCODE = 'check_violation';
    END IF;

    PERFORM fn_recalc_build(NEW.build_id);
    IF TG_OP = 'UPDATE' AND OLD.build_id <> NEW.build_id THEN
        PERFORM fn_recalc_build(OLD.build_id);
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_build_components_aiud
    AFTER INSERT OR UPDATE OR DELETE ON build_components
    FOR EACH ROW EXECUTE FUNCTION trg_build_components_check();

-- Неактивный компонент нельзя добавить в сборку
CREATE FUNCTION trg_build_components_active() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT (SELECT is_active FROM components WHERE id = NEW.component_id) THEN
        RAISE EXCEPTION 'Компонент % снят с продажи и недоступен для сборки', NEW.component_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_build_components_bi
    BEFORE INSERT OR UPDATE OF component_id ON build_components
    FOR EACH ROW EXECUTE FUNCTION trg_build_components_active();

-- Изменилась цена компонента → пересчитать сборки, где он используется
CREATE FUNCTION trg_components_price_changed() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE b bigint;
BEGIN
    FOR b IN SELECT DISTINCT build_id FROM build_components WHERE component_id = NEW.id LOOP
        PERFORM fn_recalc_build(b);
    END LOOP;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_components_price_au
    AFTER UPDATE OF price ON components
    FOR EACH ROW WHEN (OLD.price IS DISTINCT FROM NEW.price)
    EXECUTE FUNCTION trg_components_price_changed();

-- Публикация: только полная и совместимая сборка
CREATE FUNCTION trg_publications_bi() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_complete boolean; v_compat boolean;
BEGIN
    SELECT is_complete, is_compatible INTO v_complete, v_compat FROM builds WHERE id = NEW.build_id;
    IF NOT v_complete THEN
        RAISE EXCEPTION 'Нельзя опубликовать сборку: выбраны не все обязательные компоненты'
            USING ERRCODE = 'check_violation';
    END IF;
    IF NOT v_compat THEN
        RAISE EXCEPTION 'Нельзя опубликовать несовместимую сборку' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_publications_bi BEFORE INSERT ON publications
    FOR EACH ROW EXECUTE FUNCTION trg_publications_bi();

CREATE FUNCTION trg_publications_sync_public() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE builds SET is_public = true WHERE id = NEW.build_id;
        INSERT INTO event_log(user_id, event_type, entity_type, entity_id)
            VALUES (NEW.user_id, 'build_published', 'build', NEW.build_id);
    ELSE
        UPDATE builds SET is_public = false WHERE id = OLD.build_id;   -- если сборка ещё существует
    END IF;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_publications_aid AFTER INSERT OR DELETE ON publications
    FOR EACH ROW EXECUTE FUNCTION trg_publications_sync_public();

-- Удаление сборки: нельзя, если она опубликована и у других есть на неё ссылки (избранное).
-- Администратор (SET LOCAL app.is_admin = 'on') может удалять нарушающие правила сборки.
CREATE FUNCTION trg_builds_bd() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.is_public
       AND coalesce(current_setting('app.is_admin', true), '') <> 'on'
       AND EXISTS (SELECT 1 FROM favorites f
                    WHERE f.build_id = OLD.id AND f.user_id <> OLD.user_id) THEN
        RAISE EXCEPTION 'Нельзя удалить опубликованную сборку: она сохранена в избранное другими пользователями'
            USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN OLD;
END $$;
CREATE TRIGGER trg_builds_bd BEFORE DELETE ON builds
    FOR EACH ROW EXECUTE FUNCTION trg_builds_bd();

-- is_public нельзя выставить вручную без публикации
CREATE FUNCTION trg_builds_bu() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.is_public AND NOT EXISTS (SELECT 1 FROM publications WHERE build_id = NEW.id) THEN
        RAISE EXCEPTION 'Сборка становится публичной только через публикацию (publications)'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_builds_bu BEFORE UPDATE OF is_public ON builds
    FOR EACH ROW WHEN (NEW.is_public AND NOT OLD.is_public)
    EXECUTE FUNCTION trg_builds_bu();

-- Лайки и избранное — только для опубликованных (не скрытых) сборок;
-- избранное — только чужих сборок
CREATE FUNCTION trg_likes_fav_bi() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_owner bigint; v_status publication_status;
BEGIN
    SELECT b.user_id, p.status INTO v_owner, v_status
      FROM builds b LEFT JOIN publications p ON p.build_id = b.id
     WHERE b.id = NEW.build_id AND b.is_public;
    IF v_status IS DISTINCT FROM 'published' THEN
        RAISE EXCEPTION 'Действие доступно только для публичных сборок в галерее'
            USING ERRCODE = 'check_violation';
    END IF;
    IF TG_TABLE_NAME = 'favorites' AND v_owner = NEW.user_id THEN
        RAISE EXCEPTION 'В избранное можно добавлять только чужие сборки'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_likes_bi     BEFORE INSERT ON likes     FOR EACH ROW EXECUTE FUNCTION trg_likes_fav_bi();
CREATE TRIGGER trg_favorites_bi BEFORE INSERT ON favorites FOR EACH ROW EXECUTE FUNCTION trg_likes_fav_bi();

-- Счётчик лайков
CREATE FUNCTION trg_likes_count() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE builds SET likes_count = likes_count + 1 WHERE id = NEW.build_id;
    ELSE
        UPDATE builds SET likes_count = greatest(likes_count - 1, 0) WHERE id = OLD.build_id;
    END IF;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_likes_aid AFTER INSERT OR DELETE ON likes
    FOR EACH ROW EXECUTE FUNCTION trg_likes_count();

-- Журнал: регистрация, блокировка/разблокировка (актор — app.user_id, если приложение его задаёт)
CREATE FUNCTION trg_users_log() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_actor bigint := nullif(current_setting('app.user_id', true), '')::bigint;
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO event_log(user_id, event_type, entity_type, entity_id)
            VALUES (NEW.id, 'user_registered', 'user', NEW.id);
    ELSIF NEW.status <> OLD.status THEN
        INSERT INTO event_log(user_id, event_type, entity_type, entity_id, details)
            VALUES (v_actor,
                    CASE NEW.status WHEN 'blocked' THEN 'user_blocked' ELSE 'user_unblocked' END,
                    'user', NEW.id, jsonb_build_object('email', NEW.email));
    END IF;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_users_log AFTER INSERT OR UPDATE OF status ON users
    FOR EACH ROW EXECUTE FUNCTION trg_users_log();

-- =====================================================================
--  ФУНКЦИИ ДЛЯ ПРИЛОЖЕНИЯ
-- =====================================================================

-- Регистрация клиента (хэш bcrypt считает БД; можно и из C# — тогда просто INSERT)
CREATE FUNCTION fn_register_user(p_last text, p_first text, p_middle text, p_email text, p_password text)
RETURNS bigint LANGUAGE sql AS $$
    INSERT INTO users(last_name, first_name, middle_name, email, password_hash)
    VALUES (p_last, p_first, p_middle, p_email, crypt(p_password, gen_salt('bf')))
    RETURNING id
$$;

-- Авторизация: id пользователя или NULL при неверных данных;
-- заблокированный клиент войти не может
CREATE FUNCTION fn_login(p_email text, p_password text) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE u users%ROWTYPE;
BEGIN
    SELECT * INTO u FROM users WHERE email = p_email;
    IF NOT FOUND OR u.password_hash <> crypt(p_password, u.password_hash) THEN
        RETURN NULL;
    END IF;
    IF u.status = 'blocked' THEN
        RAISE EXCEPTION 'Учётная запись заблокирована' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN u.id;
END $$;

-- Копирование чужой (публичной) сборки как основы для своей
CREATE FUNCTION fn_copy_build(p_source bigint, p_user bigint, p_name text DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_new bigint; v_src builds%ROWTYPE;
BEGIN
    SELECT * INTO v_src FROM builds WHERE id = p_source;
    IF NOT FOUND OR (NOT v_src.is_public AND v_src.user_id <> p_user) THEN
        RAISE EXCEPTION 'Сборка недоступна для копирования' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO builds(name, user_id, creation_mode, copied_from_id)
        VALUES (coalesce(p_name, v_src.name || ' (копия)'), p_user, 'manual', p_source)
        RETURNING id INTO v_new;
    INSERT INTO build_components(build_id, category_id, component_id)
        SELECT v_new, category_id, component_id FROM build_components WHERE build_id = p_source;
    RETURN v_new;
END $$;

-- =====================================================================
--  ПРЕДСТАВЛЕНИЯ
-- =====================================================================

-- Каталог: компонент + характеристики одним JSON
CREATE VIEW v_component_catalog AS
SELECT c.id, cc.code AS category_code, cc.name AS category_name,
       c.name, c.manufacturer, c.model, c.price, c.is_active,
       coalesce(jsonb_object_agg(ch.name, v.value_text) FILTER (WHERE ch.id IS NOT NULL), '{}'::jsonb) AS specs
  FROM components c
  JOIN component_categories cc ON cc.id = c.category_id
  LEFT JOIN component_characteristic_values v ON v.component_id = c.id
  LEFT JOIN characteristics ch ON ch.id = v.characteristic_id
 GROUP BY c.id, cc.code, cc.name;

-- Состав сборок (конфигурация ПК / отчёт по сборке)
CREATE VIEW v_build_items AS
SELECT b.id AS build_id, b.name AS build_name, cc.sort_order, cc.name AS category_name,
       c.id AS component_id, c.name AS component_name, c.manufacturer, c.price
  FROM builds b
  JOIN build_components bc ON bc.build_id = b.id
  JOIN component_categories cc ON cc.id = bc.category_id
  JOIN components c ON c.id = bc.component_id;

-- Галерея публичных сборок
CREATE VIEW v_gallery AS
SELECT b.id AS build_id, b.name, b.total_price, b.likes_count, b.cpu_gpu_balance, b.share_token,
       p.id AS publication_id, p.published_at, p.author_comment,
       u.id AS author_id, u.first_name || ' ' || u.last_name AS author_name
  FROM publications p
  JOIN builds b ON b.id = p.build_id
  JOIN users  u ON u.id = p.user_id
 WHERE p.status = 'published';

-- Статистика использования системы (для админ-панели)
CREATE VIEW v_system_stats AS
SELECT (SELECT count(*) FROM users WHERE role = 'client')                 AS clients_total,
       (SELECT count(*) FROM users WHERE status = 'blocked')              AS clients_blocked,
       (SELECT count(*) FROM components WHERE is_active)                  AS components_active,
       (SELECT count(*) FROM builds)                                      AS builds_total,
       (SELECT count(*) FROM builds WHERE creation_mode = 'auto_ai')      AS builds_auto_ai,
       (SELECT count(*) FROM builds WHERE creation_mode = 'manual')       AS builds_manual,
       (SELECT count(*) FROM publications WHERE status = 'published')     AS publications_visible,
       (SELECT count(*) FROM likes)                                       AS likes_total,
       (SELECT count(*) FROM favorites)                                   AS favorites_total,
       (SELECT round(avg(total_price), 2) FROM builds WHERE is_complete)  AS avg_complete_build_price;
