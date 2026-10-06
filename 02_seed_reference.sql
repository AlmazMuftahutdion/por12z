-- Справочники: категории и списки характеристик.
-- aliases — варианты названия характеристики на Regard (поиск по вхождению, без регистра);
-- их стоит сверить с реальными ключами specs из JSON парсера (см. load_regard_json.py).
\set ON_ERROR_STOP on

INSERT INTO component_categories (code, name, is_required, sort_order) VALUES
 ('processors',     'Процессор',          true,  1),
 ('motherboards',   'Материнская плата',  true,  2),
 ('graphics_cards', 'Видеокарта',         true,  3),
 ('ram',            'Оперативная память', true,  4),
 ('storage',        'Накопитель',         true,  5),
 ('power_supplies', 'Блок питания',       true,  6),
 ('cases',          'Корпус',             true,  7),
 ('cooling',        'Система охлаждения', false, 8);  -- не входит в обязательные 7 по ТЗ

INSERT INTO characteristics (category_id, code, name, unit, data_type, is_required, aliases, sort_order)
SELECT cc.id, x.code, x.name, x.unit, x.dt::char_data_type, x.req, x.aliases, x.ord
FROM (VALUES
 -- Процессор
 ('processors','socket','Сокет',NULL,'text',true, ARRAY['сокет','socket'],1),
 ('processors','cores','Количество ядер',NULL,'number',false, ARRAY['общее количество ядер','количество ядер','число ядер'],2),
 ('processors','threads','Количество потоков',NULL,'number',false, ARRAY['количество потоков','число потоков'],3),
 ('processors','base_freq_ghz','Базовая частота','ГГц','number',false, ARRAY['базовая частота','тактовая частота'],4),
 ('processors','tdp_w','TDP','Вт','number',true, ARRAY['тепловыделение','tdp'],5),
 ('processors','memory_type','Тип памяти',NULL,'text',false, ARRAY['тип памяти','тип поддерживаемой памяти'],6),
 ('processors','integrated_graphics','Встроенная графика',NULL,'text',false, ARRAY['встроенное графическое ядро','встроенная графика','графическое ядро'],7),
 ('processors','perf_score','Индекс производительности (0–100)',NULL,'number',false, ARRAY[]::text[],8),
 -- Материнская плата
 ('motherboards','socket','Сокет',NULL,'text',true, ARRAY['сокет','socket'],1),
 ('motherboards','chipset','Чипсет',NULL,'text',false, ARRAY['чипсет'],2),
 ('motherboards','form_factor','Форм-фактор',NULL,'text',true, ARRAY['форм-фактор','форм фактор'],3),
 ('motherboards','memory_type','Тип памяти',NULL,'text',true, ARRAY['тип памяти','тип поддерживаемой памяти'],4),
 ('motherboards','memory_slots','Слотов памяти',NULL,'number',false, ARRAY['количество слотов памяти','слотов памяти','слоты памяти'],5),
 ('motherboards','max_memory_gb','Максимальный объём памяти','ГБ','number',false, ARRAY['максимальный объем памяти','максимальный объём памяти'],6),
 ('motherboards','m2_slots','Слотов M.2',NULL,'number',false, ARRAY['слотов m.2','количество m.2','разъемов m.2'],7),
 -- Видеокарта
 ('graphics_cards','gpu_chipset','Графический процессор',NULL,'text',false, ARRAY['графический процессор','модель графического процессора','gpu'],1),
 ('graphics_cards','memory_gb','Объём видеопамяти','ГБ','number',false, ARRAY['объем видеопамяти','объём видеопамяти','видеопамять'],2),
 ('graphics_cards','memory_type','Тип памяти',NULL,'text',false, ARRAY['тип видеопамяти','тип памяти'],3),
 ('graphics_cards','tdp_w','Энергопотребление','Вт','number',true, ARRAY['энергопотребление','тепловыделение','tdp','tgp'],4),
 ('graphics_cards','recommended_psu_w','Рекомендуемая мощность БП','Вт','number',false, ARRAY['рекомендуемый блок питания','рекомендуемая мощность блока питания','рекомендуемая мощность бп'],5),
 ('graphics_cards','length_mm','Длина','мм','number',true, ARRAY['длина видеокарты','длина'],6),
 ('graphics_cards','perf_score','Индекс производительности (0–100)',NULL,'number',false, ARRAY[]::text[],7),
 -- Оперативная память
 ('ram','memory_type','Тип памяти',NULL,'text',true, ARRAY['тип памяти','тип'],1),
 ('ram','capacity_gb','Общий объём','ГБ','number',true, ARRAY['объем комплекта','объём комплекта','общий объем','объем памяти','объём памяти'],2),
 ('ram','modules_count','Количество модулей',NULL,'number',false, ARRAY['количество модулей','модулей в комплекте'],3),
 ('ram','frequency_mhz','Частота','МГц','number',false, ARRAY['тактовая частота','частота памяти','частота'],4),
 -- Накопитель
 ('storage','capacity_gb','Объём','ГБ','number',true, ARRAY['объем накопителя','объём накопителя','объем','объём'],1),
 ('storage','interface','Интерфейс',NULL,'text',false, ARRAY['интерфейс','подключение'],2),
 ('storage','form_factor','Форм-фактор',NULL,'text',false, ARRAY['форм-фактор','форм фактор'],3),
 ('storage','read_speed_mbs','Скорость чтения','МБ/с','number',false, ARRAY['скорость чтения'],4),
 ('storage','write_speed_mbs','Скорость записи','МБ/с','number',false, ARRAY['скорость записи'],5),
 -- Блок питания
 ('power_supplies','power_w','Мощность','Вт','number',true, ARRAY['мощность'],1),
 ('power_supplies','efficiency','Сертификат 80 PLUS',NULL,'text',false, ARRAY['80 plus','сертификат'],2),
 ('power_supplies','form_factor','Форм-фактор',NULL,'text',false, ARRAY['форм-фактор','форм фактор'],3),
 -- Корпус
 ('cases','form_factors','Поддерживаемые форм-факторы плат',NULL,'text',true, ARRAY['форм-фактор материнской платы','поддерживаемые форм-факторы','форм-фактор плат','совместимые материнские платы'],1),
 ('cases','max_gpu_length_mm','Макс. длина видеокарты','мм','number',false, ARRAY['максимальная длина видеокарты','длина видеокарты'],2),
 ('cases','color','Цвет',NULL,'text',false, ARRAY['цвет'],3),
 -- Охлаждение
 ('cooling','sockets','Поддерживаемые сокеты',NULL,'text',true, ARRAY['сокет','совместимость с сокетами','поддерживаемые сокеты'],1),
 ('cooling','tdp_w','Рассеиваемая мощность','Вт','number',false, ARRAY['рассеиваемая мощность','tdp'],2),
 ('cooling','cooler_type','Тип охлаждения',NULL,'text',false, ARRAY['тип охлаждения','тип'],3),
 ('cooling','height_mm','Высота','мм','number',false, ARRAY['высота'],4)
) AS x(cat, code, name, unit, dt, req, aliases, ord)
JOIN component_categories cc ON cc.code = x.cat;
