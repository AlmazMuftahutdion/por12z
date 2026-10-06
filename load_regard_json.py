#!/usr/bin/env python3
"""
Загрузка JSON-файлов парсера Regard (processors_120.json, motherboards_120.json, ...) в БД.

    pip install psycopg2-binary
    python load_regard_json.py --dsn "postgresql://user:pass@localhost/pc_configurator" *.json

Повторный запуск безопасен (upsert по source='regard' + external_id).
Характеристики сопоставляются с таблицей characteristics через characteristics.aliases
(вхождение алиаса в название характеристики на сайте, без регистра).
Все исходные характеристики дополнительно сохраняются в components.raw_specs (jsonb),
а в конце печатается список «непонятых» названий — их можно добавить в aliases.
"""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

import psycopg2
from psycopg2.extras import Json

# ключ категории в JSON (поле "category") -> characteristics/component_categories.code
CATEGORY_CODES = {
    "processors", "motherboards", "power_supplies", "cases",
    "graphics_cards", "cooling", "ram", "storage",
}
NAME_PREFIX = re.compile(
    r"^(Процессор|Материнская плата|Блок питания|Корпус|Видеокарта|Кулер для процессора|"
    r"Кулер|Система охлаждения|Оперативная память|Модуль памяти|Накопитель SSD|SSD накопитель|SSD)\s+",
    re.IGNORECASE,
)
NUM = re.compile(r"\d+(?:[.,]\d+)?")


def split_name(name: str, brand: str | None):
    """Производитель и модель из наименования товара."""
    rest = NAME_PREFIX.sub("", name).strip()
    if brand:
        model = re.sub(rf"^{re.escape(brand)}\s+", "", rest, flags=re.IGNORECASE) or rest
        return brand, model
    parts = rest.split(" ", 1)
    return parts[0], (parts[1] if len(parts) > 1 else rest)


def to_number(value: str):
    m = NUM.search(value.replace("\xa0", " "))
    return float(m.group(0).replace(",", ".")) if m else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dsn", required=True)
    ap.add_argument("files", nargs="+")
    args = ap.parse_args()

    conn = psycopg2.connect(args.dsn)
    cur = conn.cursor()

    cur.execute("SELECT id, code FROM component_categories")
    cat_id = {code: i for i, code in cur.fetchall()}

    cur.execute("SELECT category_id, id, name, data_type, aliases FROM characteristics")
    chars: dict[int, list] = {}
    for cid, chid, cname, dtype, aliases in cur.fetchall():
        chars.setdefault(cid, []).append((chid, dtype, [a.lower() for a in aliases] + [cname.lower()]))

    unmatched = Counter()
    total = skipped = 0

    for path in args.files:
        items = json.loads(Path(path).read_text(encoding="utf-8"))
        for it in items:
            code = it.get("category")
            if code not in CATEGORY_CODES or code not in cat_id:
                print(f"[skip] {path}: неизвестная категория {code!r}", file=sys.stderr)
                skipped += 1
                continue
            price = it.get("price")
            if price is None or price < 100:        # ограничение БД: цена ≥ 100 ₽
                print(f"[skip] {it.get('name')}: некорректная цена {price!r}", file=sys.stderr)
                skipped += 1
                continue

            specs = it.get("specs") or {}
            brand = specs.get("brand")
            manufacturer, model = split_name(it["name"], brand)
            cid = cat_id[code]

            cur.execute(
                """
                INSERT INTO components (category_id, name, manufacturer, model, price,
                                        source, external_id, source_url, raw_specs)
                VALUES (%s,%s,%s,%s,%s,'regard',%s,%s,%s)
                ON CONFLICT (source, external_id) DO UPDATE
                   SET name = EXCLUDED.name, manufacturer = EXCLUDED.manufacturer,
                       model = EXCLUDED.model, price = EXCLUDED.price,
                       source_url = EXCLUDED.source_url, raw_specs = EXCLUDED.raw_specs
                RETURNING id
                """,
                (cid, it["name"][:300], manufacturer[:100], model[:250], price,
                 str(it["id"]), it.get("url"), Json(specs)),
            )
            comp_id = cur.fetchone()[0]

            cur.execute("DELETE FROM component_characteristic_values WHERE component_id = %s", (comp_id,))
            used = set()
            for key, value in specs.items():
                if key in ("brand", "sku", "brief") or not value:
                    continue
                k = key.lower()
                best = None                      # самый длинный подошедший алиас — самый точный
                for chid, dtype, aliases in chars.get(cid, []):
                    if chid in used:
                        continue
                    for a in aliases:
                        if a in k and (best is None or len(a) > best[0]):
                            best = (len(a), chid, dtype)
                if best is None:
                    unmatched[(code, key)] += 1
                    continue
                _, chid, dtype = best
                num = to_number(str(value)) if dtype == "number" else None
                if dtype == "number" and num is None:
                    unmatched[(code, key)] += 1
                    continue
                used.add(chid)
                cur.execute(
                    "INSERT INTO component_characteristic_values VALUES (%s,%s,%s,%s,%s)",
                    (comp_id, chid, cid, str(value), num),
                )
            total += 1

    conn.commit()
    print(f"Загружено/обновлено компонентов: {total}, пропущено: {skipped}")
    if unmatched:
        print("\nНесопоставленные характеристики (добавьте в characteristics.aliases при необходимости):")
        for (code, key), n in unmatched.most_common(40):
            print(f"  {code:15} {key!r}  ×{n}")


if __name__ == "__main__":
    main()
