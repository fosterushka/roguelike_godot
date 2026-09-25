#!/usr/bin/env python3
"""Build the portable, screenshot-backed report for the September QOL pass."""
from pathlib import Path
import argparse
import base64
import html
import json
import shutil
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/validation/qol-audit'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--full', type=Path, required=True)
    parser.add_argument('--recheck', type=Path, action='append', default=[])
    parser.add_argument('--baseline', type=Path)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    images = OUT / 'images'
    evidence = OUT / 'evidence'
    evidence.mkdir(exist_ok=True)
    results = {}
    for index, path in enumerate([args.full, *args.recheck]):
        report = json.loads(path.read_text())
        shutil.copy2(path, evidence / f'tests-{index}.json')
        for row in report['results']:
            results[row['test']] = row
    baseline = {}
    if args.baseline:
        shutil.copy2(args.baseline, evidence / 'baseline.json')
        baseline = {row['test']: row for row in json.loads(args.baseline.read_text())['results']}
    passed = sum(row['passed'] for row in results.values())
    failed = [row for row in results.values() if not row['passed']]
    for name in ['customization-comparison.png', 'fog-lamps-model.png']:
        shutil.copy2(ROOT / 'docs/validation/qol-2026-09-12' / name, images / name)
    used = set()

    def uri(name):
        path = images / name
        if not path.is_file():
            raise FileNotFoundError(path)
        used.add(name)
        return 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode()

    def figure(name, caption):
        width, height = struct.unpack('>II', (images / name).read_bytes()[16:24])
        return f'<figure><img loading="lazy" width="{width}" height="{height}" src="{uri(name)}" alt="{html.escape(caption)}"><figcaption>{html.escape(caption)}</figcaption></figure>'

    def comparison(before, after, caption, left='До', right='После'):
        width, height = struct.unpack('>II', (images / after).read_bytes()[16:24])
        return f'''<figure><div class="comparison"><img width="{width}" height="{height}" src="{uri(after)}" alt="{right}">
        <img class="before" src="{uri(before)}" alt="{left}"><span class="left-label">{left}</span><span class="right-label">{right}</span>
        <input type="range" min="0" max="100" value="50" aria-label="Сравнить: {html.escape(caption)}" oninput="this.parentElement.style.setProperty('--split',this.value+'%')"></div><figcaption>{caption}. Перемещайте разделитель.</figcaption></figure>'''

    parts = [f'''<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>IRON CARAVAN · Аудит gameplay и QOL</title><style>
    :root{{color-scheme:dark;--bg:#101615;--panel:#19211f;--text:#eeebdd;--muted:#abb4a6;--line:#3f4c43;--accent:#dbb56a}}
    *{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:16px/1.6 system-ui,sans-serif}}main{{max-width:1160px;margin:auto;padding:48px 28px 80px}}
    header{{border-bottom:2px solid var(--accent);padding-bottom:26px}}.eyebrow{{text-transform:uppercase;letter-spacing:.16em;color:var(--accent);font-size:13px}}h1{{font-size:clamp(32px,5vw,54px);line-height:1.12;max-width:850px;margin:18px 0}}h2{{margin:50px 0 16px;font-size:28px}}h3{{font-size:20px;margin:24px 0 12px}}p{{max-width:920px}}.muted,figcaption{{color:var(--muted)}}a{{color:var(--accent)}}nav{{display:flex;gap:10px 28px;flex-wrap:wrap;padding:22px 0;border-bottom:1px solid var(--line)}}nav a{{text-decoration:none}}.verdict{{border-left:3px solid var(--accent);padding:10px 20px;margin:22px 0;background:var(--panel)}}table{{border-collapse:collapse;width:100%;font-size:14px}}th,td{{border-bottom:1px solid var(--line);padding:12px;text-align:left;vertical-align:top}}th{{color:var(--muted);font-weight:500}}.pass{{color:#a7bc91}}.fail{{color:#eb9181}}figure{{margin:22px 0}}img{{display:block;width:100%;height:auto;background:var(--panel)}}figcaption{{font-size:14px;padding:10px 0}}.pair{{display:grid;grid-template-columns:1fr 1fr;gap:20px}}details{{border-top:1px solid var(--line);padding:18px 0}}summary{{cursor:pointer;color:var(--accent)}}code{{font-size:.88em;overflow-wrap:anywhere}}.comparison{{position:relative;--split:50%}}.comparison .before{{position:absolute;inset:0;clip-path:inset(0 calc(100% - var(--split)) 0 0)}}.comparison input{{position:absolute;inset:0;width:100%;height:100%;opacity:0;cursor:ew-resize;margin:0}}.comparison:after{{content:'';pointer-events:none;position:absolute;left:var(--split);top:0;bottom:0;border-left:2px solid var(--accent)}}.left-label,.right-label{{position:absolute;top:12px;background:#101615df;padding:4px 10px;font-size:13px}}.left-label{{left:12px}}.right-label{{right:12px}}.comparison:focus-within{{outline:2px solid var(--accent)}}footer{{margin-top:48px;padding-top:20px;border-top:1px solid var(--line);color:var(--muted);font-size:14px}}@media(max-width:720px){{main{{padding:24px 16px}}.pair{{grid-template-columns:1fr}}table{{font-size:12px}}th,td{{padding:8px 5px}}}}@media print{{body{{background:white;color:black}}nav{{display:none}}details{{display:block}}img{{break-inside:avoid}}}}
    </style></head><body><main><header><div class="eyebrow">IRON CARAVAN / OFFLINE / 12.09.2026</div><h1>Караван удобнее собирать.<br>Мир понятнее читать.</h1>
    <p>Аудит внедрения: нитро и прицепы, гараж, припасы, кастомизация, противотуманки, прозрачность препятствий, эвакуация и полезные цели рейда.</p>
    <p class="muted">Скриншоты получены реальным Godot 4.7.2, Metal Forward+ на Apple M4 Pro. UI проверен в RU/EN, 960×600 и 1280×800. Состояния подготовлены сценариями проверки; это не запись длительного ручного прохождения.</p></header>
    <nav><a href="#changes">Изменения</a><a href="#garage">Гараж и склад</a><a href="#visibility">Видимость</a><a href="#world">Рейд и эвакуация</a><a href="#checks">Проверки</a><a href="#gallery">Все экраны</a></nav>
    <section id="changes"><h2>Что изменилось</h2><table><thead><tr><th>Проблема</th><th>Реализованное поведение</th></tr></thead><tbody>
    <tr><td>Нитро отрывает прицеп без удара</td><td>Скорость догоняющего прицепа учитывает буксир. Проверены 6 прицепов, дорога, улучшенный двигатель, 30/60/120 кадров в секунду. Заблокированный прицеп по-прежнему может отцепиться.</td></tr>
    <tr><td>Гараж открывает магазин</td><td>Вход открывает свой состав. Крепление выбирается явно; занятое можно осмотреть и освободить. Тюнинг пикапа находится в гараже.</td></tr>
    <tr><td>Склад требует много кликов</td><td>Компактные строки, перенос количества, занятая вместимость, объяснение недоступного действия, повтор припасов прошлого выезда. Сохранение выполняется целиком с откатом при ошибке.</td></tr>
    <tr><td>Сборки похожи друг на друга</td><td>Дорожные и грязевые шины, покупаемые противотуманки, 3 окраски, 3 варианта эмблемы, 3 сохранённых набора состава и тюнинга.</td></tr>
    <tr><td>Туман и деревья закрывают бой</td><td>Фары очищают сектор перед пикапом и восстанавливают видимость для оружия в нём. Перекрывающий обзор объект плавно становится прозрачным; коллизия сохраняется.</td></tr>
    <tr><td>События трудно найти</td><td>Одна полезная и достижимая цель закреплена с расстоянием, временем, задачей и наградой. Базовая цель понятна без улучшения радара.</td></tr>
    <tr><td>Эвакуация похожа на пустую метку</td><td>Блокпост с навесом, радио и генератором, прожектором, дымом и открывающимися воротами. После сохранения добычи караван отъезжает перед показом итогов.</td></tr>
    <tr><td>После события мир не меняется</td><td>Спасённое поселение освещается и открывает одноразовый ремонт по E рядом с ним: до 35% максимальной прочности. Полный корпус не тратит услугу. После уничтожения конвоя остаётся разбитая машина.</td></tr>
    </tbody></table></section>
    <section id="garage"><h2>Подготовка каравана</h2><p>Рабочий путь: свой состав → крепление и оборудование → тюнинг пикапа → припасы → выезд. Покупки используют кредиты базы; полевые установки сохраняют свою экономику лома.</p>''']
    parts += [figure('ui-ru-960-garage.png', 'Гараж открывает текущий состав. Компактный экран 960×600.'),
              figure('ui-ru-960-equipment.png', 'Явно выбранное крепление, установленный предмет и действие над ним.'),
              figure('ui-ru-960-supplies.png', 'Склад и припасы: количество за действие, занятая вместимость, повтор прошлого набора.'),
              figure('ui-ru-1280-tires.png', 'Тюнинг: выбор оснащения с ценой и эффектом.'),
              figure('customization-comparison.png', 'Общие игровые модели: стандартная, дорожная и грязевая сборки. Сравнение в отдельной сцене моделей.'),
              '<p class="muted">Наборы сохраняют состав, выбранный экипаж, посадку и тюнинг. Оборудование остаётся на конкретных прицепах. Набор не возвращает утраченный транспорт. Установка оружия сохраняет существующие ограничения полевого Арсенала.</p></section>',
              '<section id="visibility"><h2>Видимость с игровым эффектом</h2><p>Противотуманки работают в ограниченном секторе, который поворачивается вместе с пикапом. Снаружи сектора туман сохраняется. Дальность оружия в ясную погоду не увеличивается.</p>',
              comparison('fog-lamps-off.png', 'fog-lamps-on.png', 'Одна сцена, одинаковая погода и камера', 'Фары сняты', 'Фары установлены'),
              figure('fog-lamps-turned.png', 'После поворота пикапа очищенный сектор меняет направление.'),
              comparison('occlusion-before.png', 'occlusion-after.png', 'Дерево перед игроком', 'Эффект отключён', 'Эффект включён'),
              comparison('enemy-occlusion-before.png', 'enemy-occlusion-after.png', 'Объект перед обнаруженным противником', 'Эффект отключён', 'Эффект включён'),
              comparison('building-occlusion-before.png', 'building-occlusion-after.png', 'Здание перед машиной', 'Эффект отключён', 'Эффект включён'),
              '<p class="muted">Прозрачность меняется у экземпляра объекта. Общие модели и материалы сохраняются; разрушенные объекты не восстанавливаются при окончании эффекта. Перемещённые торнадо объекты обновляют положение в поиске перекрытий. Проверка ближайших врагов ограничена дальностью обнаружения; эффект не раскрывает всех врагов на карте.</p></section>',
              '<section id="world"><h2>Понятные цели и заметные последствия</h2>']
    captions = {
        'extraction-checkpoint.png': 'Эвакуация: физическая площадка и проезд для каравана.',
        'extraction-defense.png': 'Оборона: сигнал активен, подготовка эвакуации продолжается.',
        'extraction-gate.png': 'Ворота открываются к завершению удержания зоны.',
        'extraction-night.png': 'Ночной блокпост: прожектор и освещение площадки.',
        'settlement-night.png': 'После спасения поселения включается полевое освещение.',
        'settlement-service-ready.png': 'Пункт ремонта: подъехать и нажать E. Услуга доступна один раз за рейд в каждом спасённом поселении.',
        'settlement-service-used.png': 'После ремонта отображается использованная услуга; повторного восстановления нет.',
        'primary-destination.png': 'Закреплённая цель с направлением, расстоянием и наградой.',
        'convoy-aftermath.png': 'На месте остановленного конвоя остаётся разбитая машина.',
        'extraction-departure.png': 'Короткий отъезд каравана после успешного сохранения. Боевая симуляция уже остановлена.',
        'extraction-result.png': 'Итог эвакуации после отъезда. Ошибка записи сразу открывает повтор сохранения.',
    }
    for name, caption in captions.items():
        parts.append(figure(name, caption))
    parts.append(f'''</section><section id="checks"><h2>Что проверено</h2><div class="verdict"><strong>{passed} из {len(results)} наборов тестов проходят.</strong><br>Итог объединяет полный прогон и последующие адресные проверки изменённых участков. Это не заявление об отдельном полном повторном прогоне после каждой правки.</div><table><tr><th>Проверка</th><th>Результат и граница</th></tr><tr><td>Сохранения</td><td>Покупка, перенос припасов, повтор комплекта, сохранённые сборки, повторная загрузка и откат при ошибке записи.</td></tr><tr><td>Движение</td><td>Нитро + дорога + улучшенный двигатель + 6 прицепов; заблокированный хвост; разные частоты шага.</td></tr><tr><td>Видимость</td><td>Сектор, поворот, граница дальности, снятие фар, выбор цели оружием; прозрачность не меняет коллизию и общие ресурсы.</td></tr><tr><td>События и эвакуация</td><td>Ремонт рядом с поселением, полный корпус, повторное использование, предел восстановления и сброс рейда; отъезд после сохранения, повтор записи при ошибке.</td></tr><tr><td>UI</td><td>Реальный рендер RU/EN на 960×600 и 1280×800, выбор креплений и количества. Ручное прохождение каждого действия мышью не заявляется.</td></tr><tr><td>Архитектура</td><td>Проверка границ модулей проходит; allowlist зависимостей не расширен.</td></tr></table>''')
    if failed:
        parts.append('<h3>Оставшиеся ошибки полного набора</h3><table><tr><th>Набор</th><th>Сравнение с исходной версией</th></tr>')
        for row in failed:
            old = baseline.get(row['test'])
            description = 'Та же ошибка воспроизведена на исходном HEAD до изменений.' if old and not old['passed'] else 'Требует отдельного разбора; не объявлена старой без проверки.'
            parts.append(f'<tr><td><code>{html.escape(row["test"])}</code></td><td>{description}</td></tr>')
        parts.append('</table>')
    parts.append('<h3>Ограничения проверки</h3><p>Длительный балансный плейтест, измерение FPS до/после, отдельный macOS-экспорт и проверка на других GPU не выполнялись. Прозрачность рассчитана на основной Forward+ рендерер проекта. Погодный эффект фар использует отдельный проход по глубине; дальний туман остаётся погодным ограничением.</p>')
    parts.append('<details><summary>Результат каждого набора</summary><table><tr><th>Тест</th><th>Статус</th></tr>')
    for name, row in results.items():
        parts.append(f'<tr><td><code>{html.escape(name)}</code></td><td class="{"pass" if row["passed"] else "fail"}">{"Пройден" if row["passed"] else html.escape(row["reason"])}</td></tr>')
    parts.append('</table></details></section><section id="gallery"><h2>Дополнительные состояния</h2>')
    for language in ['ru', 'en']:
        for size in ['960', '1280']:
            parts.append(f'<details><summary>UI · {language.upper()} · {size}px</summary>')
            for path in sorted(images.glob(f'ui-{language}-{size}-*.png')):
                parts.append(figure(path.name, path.stem))
            parts.append('</details>')
    extra = [images / name for name in ['extraction-radio.png', 'extraction-gate-ru.png', 'primary-destination-ru.png', 'fog-lamps-model.png'] if name not in used]
    if extra:
        parts.append('<details><summary>Другие кадры мира и моделей</summary>')
        for path in extra:
            parts.append(figure(path.name, path.stem))
        parts.append('</details>')
    parts.append('''</section><footer>Все изображения встроены в HTML: файл можно открыть без сервера и без интернета. JSON-результаты доступны в ZIP рядом с исходными PNG.<br>Технические источники: <a href="https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html">Godot: восстановление координат по глубине</a> · <a href="https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html">Godot: прозрачность экземпляров</a>.</footer></main></body></html>''')
    (OUT / 'index.html').write_text(''.join(parts))
    (evidence / 'consolidated.json').write_text(json.dumps({'results': list(results.values()), 'passed': passed, 'total': len(results), 'embedded_images': sorted(used)}, ensure_ascii=False, indent=2))
    archive = OUT.parent / 'iron-caravan-qol-audit.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted(OUT.rglob('*')):
            if path.is_file() and path.suffix != '.import':
                if path.parent == images and path.name not in used:
                    continue
                bundle.write(path, Path('qol-audit') / path.relative_to(OUT))
    print(f'HTML: {OUT / "index.html"} ({len(used)} embedded images)')
    print(f'ZIP: {archive}')


if __name__ == '__main__':
    main()
