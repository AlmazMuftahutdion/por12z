-- Автотест ограничений и триггеров. Запуск после 01 и 02: psql -d db -f tests.sql
-- Всё выполняется в транзакции и откатывается.
\set ON_ERROR_STOP off
\set ON_ERROR_ROLLBACK on
\set VERBOSITY terse
BEGIN;

-- helper: добавить компонент с характеристиками {code: value}
CREATE FUNCTION pg_temp.mk(p_cat text, p_name text, p_price numeric, p_spec jsonb) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_cat smallint; r record;
BEGIN
    SELECT id INTO v_cat FROM component_categories WHERE code = p_cat;
    INSERT INTO components(category_id, name, manufacturer, model, price)
        VALUES (v_cat, p_name, split_part(p_name, ' ', 1), p_name, p_price) RETURNING id INTO v_id;
    FOR r IN SELECT ch.id AS cid, ch.data_type, j.value FROM jsonb_each_text(p_spec) j
             JOIN characteristics ch ON ch.category_id = v_cat AND ch.code = j.key LOOP
        IF r.data_type = 'number' THEN
            INSERT INTO component_characteristic_values VALUES (v_id, r.cid, v_cat, r.value, r.value::numeric);
        ELSE
            INSERT INTO component_characteristic_values VALUES (v_id, r.cid, v_cat, r.value, NULL);
        END IF;
    END LOOP;
    RETURN v_id;
END $$;

CREATE TEMP TABLE ids(k text PRIMARY KEY, v bigint);
INSERT INTO ids SELECT 'cpu_am5', pg_temp.mk('processors','AMD Ryzen 7 7800X3D',30000,'{"socket":"AM5","tdp_w":120,"perf_score":85}');
INSERT INTO ids SELECT 'cpu_1700', pg_temp.mk('processors','Intel Core i5-14400',18000,'{"socket":"LGA1700","tdp_w":65,"perf_score":55}');
INSERT INTO ids SELECT 'mb_am5', pg_temp.mk('motherboards','ASUS B650M',12000,'{"socket":"AM5","form_factor":"Micro-ATX","memory_type":"DDR5","memory_slots":4,"max_memory_gb":128}');
INSERT INTO ids SELECT 'ram_ddr5', pg_temp.mk('ram','Kingston DDR5 32GB',9000,'{"memory_type":"DDR5","capacity_gb":32,"modules_count":2}');
INSERT INTO ids SELECT 'ram_ddr4', pg_temp.mk('ram','Kingston DDR4 16GB',4000,'{"memory_type":"DDR4","capacity_gb":16,"modules_count":2}');
INSERT INTO ids SELECT 'gpu', pg_temp.mk('graphics_cards','MSI RTX 4070',60000,'{"tdp_w":200,"length_mm":300,"perf_score":75}');
INSERT INTO ids SELECT 'ssd', pg_temp.mk('storage','Samsung 980 1TB',7000,'{"capacity_gb":1000}');
INSERT INTO ids SELECT 'psu_500', pg_temp.mk('power_supplies','Deepcool 450W',4000,'{"power_w":450}');
INSERT INTO ids SELECT 'psu_750', pg_temp.mk('power_supplies','Corsair 750W',9000,'{"power_w":750}');
INSERT INTO ids SELECT 'case_atx', pg_temp.mk('cases','NZXT H5',8000,'{"form_factors":"ATX, mATX, Mini-ITX","max_gpu_length_mm":365}');
INSERT INTO ids SELECT 'case_itx', pg_temp.mk('cases','Cooler Master NR200',9000,'{"form_factors":"Mini-ITX","max_gpu_length_mm":330}');

INSERT INTO users(last_name, first_name, email, password_hash, role)
    VALUES ('Админов','Админ','admin@test.ru','x','admin'), ('Иванов','Иван','ivan@test.ru','x','client'),
           ('Петров','Пётр','petr@test.ru','x','client');

CREATE FUNCTION pg_temp.add(p_build bigint, p_cat text, p_key text) RETURNS void LANGUAGE sql AS $$
    INSERT INTO build_components(build_id, category_id, component_id)
    SELECT p_build, cc.id, (SELECT v FROM ids WHERE k = p_key) FROM component_categories cc WHERE cc.code = p_cat
$$;

\echo '--- 1. цена < 100 ₽ → ОШИБКА'
INSERT INTO components(category_id, name, manufacturer, model, price) VALUES (1,'x','x','x',99);

\echo '--- 2. блокировка администратора → ОШИБКА'
UPDATE users SET status = 'blocked' WHERE email = 'admin@test.ru';

\echo '--- 3. заблокированный клиент не входит → ОШИБКА; активный с верным паролем → id'
UPDATE users SET password_hash = crypt('pw', gen_salt('bf')) WHERE email IN ('ivan@test.ru','petr@test.ru');
SELECT fn_login('ivan@test.ru','pw') IS NOT NULL AS login_ok, fn_login('ivan@test.ru','bad') IS NULL AS bad_pw_null;
UPDATE users SET status = 'blocked' WHERE email = 'petr@test.ru';
SELECT fn_login('petr@test.ru','pw');
UPDATE users SET status = 'active' WHERE email = 'petr@test.ru';

INSERT INTO builds(name, user_id) SELECT 'Игровая', id FROM users WHERE email = 'ivan@test.ru';
CREATE TEMP TABLE b AS SELECT id FROM builds WHERE name = 'Игровая';

\echo '--- 4. CPU AM5 + плата AM5 → ок; CPU LGA1700 вместо него → ОШИБКА (сокет)'
SELECT pg_temp.add((SELECT id FROM b),'processors','cpu_am5');
SELECT pg_temp.add((SELECT id FROM b),'motherboards','mb_am5');
UPDATE build_components SET component_id = (SELECT v FROM ids WHERE k='cpu_1700')
 WHERE build_id = (SELECT id FROM b) AND category_id = 1;

\echo '--- 5. DDR4 к плате DDR5 → ОШИБКА; DDR5 → ок'
SELECT pg_temp.add((SELECT id FROM b),'ram','ram_ddr4');
SELECT pg_temp.add((SELECT id FROM b),'ram','ram_ddr5');

\echo '--- 6. БП 450 Вт (нужно ≥470) при CPU 120 + GPU 200 → ОШИБКА; 750 → ок'
SELECT pg_temp.add((SELECT id FROM b),'graphics_cards','gpu');
SELECT pg_temp.add((SELECT id FROM b),'power_supplies','psu_500');
SELECT pg_temp.add((SELECT id FROM b),'power_supplies','psu_750');

\echo '--- 7. корпус Mini-ITX для Micro-ATX платы → ОШИБКА'
SELECT pg_temp.add((SELECT id FROM b),'cases','case_itx');

\echo '--- 8. публикация неполной сборки (нет SSD и корпуса) → ОШИБКА'
INSERT INTO publications(build_id, user_id, author_comment) SELECT id, (SELECT id FROM users WHERE email='ivan@test.ru'), 'тест' FROM b;

SELECT pg_temp.add((SELECT id FROM b),'storage','ssd');
SELECT pg_temp.add((SELECT id FROM b),'cases','case_atx');

\echo '--- 9. итог по сборке: цена=30000+12000+9000+60000+7000+9000+8000=135000, complete, compatible, баланс'
SELECT total_price, is_complete, is_compatible, cpu_gpu_balance, cpu_gpu_diff FROM builds WHERE id = (SELECT id FROM b);

\echo '--- 10. публикация полной → ок, is_public=true'
INSERT INTO publications(build_id, user_id, author_comment) SELECT id, (SELECT id FROM users WHERE email='ivan@test.ru'), 'тест' FROM b;
SELECT is_public FROM builds WHERE id = (SELECT id FROM b);

\echo '--- 11. удаление обязательного компонента из публичной сборки → ОШИБКА'
DELETE FROM build_components WHERE build_id = (SELECT id FROM b) AND category_id = 5;

\echo '--- 12. лайк/избранное: чужой ок; в избранное своей → ОШИБКА; лайк на приватную → ОШИБКА'
INSERT INTO likes(user_id, build_id) SELECT u.id, b.id FROM users u, b WHERE u.email = 'petr@test.ru';
INSERT INTO favorites(user_id, build_id) SELECT u.id, b.id FROM users u, b WHERE u.email = 'petr@test.ru';
INSERT INTO favorites(user_id, build_id) SELECT u.id, b.id FROM users u, b WHERE u.email = 'ivan@test.ru';
SELECT likes_count FROM builds WHERE id = (SELECT id FROM b);
INSERT INTO builds(name, user_id) SELECT 'Приватная', id FROM users WHERE email='ivan@test.ru';
INSERT INTO likes(user_id, build_id) SELECT u.id, bb.id FROM users u, builds bb WHERE u.email='petr@test.ru' AND bb.name='Приватная';

\echo '--- 13. удаление публичной сборки, сохранённой в избранное другим → ОШИБКА; админом → ок'
DELETE FROM builds WHERE id = (SELECT id FROM b);
SAVEPOINT s; SET LOCAL app.is_admin = 'on';
DELETE FROM builds WHERE id = (SELECT id FROM b);
SELECT count(*) AS builds_left_named_igrovaya FROM builds WHERE name = 'Игровая';
ROLLBACK TO s;

\echo '--- 14. копирование чужой сборки'
SELECT fn_copy_build((SELECT id FROM b), (SELECT id FROM users WHERE email='petr@test.ru')) IS NOT NULL AS copied;
SELECT name, total_price, is_complete, is_public FROM builds WHERE copied_from_id = (SELECT id FROM b);

\echo '--- 15. автосборка без бюджета → ОШИБКА'
INSERT INTO builds(name, user_id, creation_mode) VALUES ('AI', 1, 'auto_ai');

\echo '--- 16. изменение цены пересчитывает сборку'
UPDATE components SET price = 31000 WHERE id = (SELECT v FROM ids WHERE k='cpu_am5');
SELECT total_price FROM builds WHERE id = (SELECT id FROM b);

\echo '--- журнал и статистика'
SELECT event_type, count(*) FROM event_log GROUP BY 1 ORDER BY 1;
SELECT * FROM v_system_stats;
ROLLBACK;
