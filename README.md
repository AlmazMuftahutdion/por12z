# БД «Конфигуратор ПК с ИИ» (PostgreSQL)

    createdb pc_configurator
    psql -d pc_configurator -f 01_schema.sql
    psql -d pc_configurator -f 02_seed_reference.sql   
    psql -d pc_configurator -f tests.sql               # автотесты
    python load_regard_json.py --dsn postgresql://... processors_120.json motherboards_120.json ...

Таблицы: component_categories, characteristics, components, component_characteristic_values,
users, builds, build_components, publications, favorites, likes, event_log, news.
Представления: v_component_catalog, v_build_items, v_gallery, v_system_stats.
Функции: fn_register_user, fn_login, fn_copy_build, fn_build_issues

Что приложение должно задавать в сессии:
- `SET LOCAL app.is_admin = 'on'` — админ может удалять публичные сборки, на которые есть ссылки;
- `SET LOCAL app.user_id = '<id>'` — кто выполнил действие (для журнала блокировок).
