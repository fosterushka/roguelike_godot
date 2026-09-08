"""Build the visual review document from actual Godot captures, never mockups."""
from html import escape
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'docs/validation/model-revision'
ROWS = [
    ('buggy', 'Buggy', 'Плоский капот, пустая кабина и декоративный каркас.', 'Открытая трубчатая рама, сиденья, двигатель, подвеска и отдельные панели.'),
    ('keep', 'Keep / Raider', 'Коробчатый кузов со слабо различимыми узлами.', 'Отдельная бронированная кабина, кузов, ходовая и оружейная установка.'),
    ('repair-crawler', 'Repair crawler', 'Глухие боковины вместо читаемой гусеничной ходовой.', 'Гусеничный механизм, ремонтное оборудование и рабочая кабина.'),
    ('leviathan', 'Leviathan', 'Большие коробки вместо корпуса, гусениц и боевых модулей.', 'Составной бронекорпус, ходовая и встроенные боевые модули.'),
    ('wreck-bike', 'Обломки мотоцикла', 'Исходная машина с уплощёнными деталями.', 'Повреждённая конструкция с отдельными сломанными деталями.'),
    ('wreck-buggy', 'Обломки buggy', 'Целая ходовая и сплющенный каркас.', 'Разрушенный каркас, деформированные панели и открытые механизмы.'),
    ('wreck-jammer', 'Обломки jammer', 'Уменьшенная по высоте исходная машина.', 'Повреждения корпуса и оборудования с сохранением узнаваемого типа машины.'),
    ('wreck-crawler', 'Обломки crawler', 'Плоский цельный блок.', 'Открытые повреждённые механизмы и разрушенный корпус.'),
    ('wreck-minelayer', 'Обломки minelayer', 'Сдавленный вариант целой машины.', 'Отдельная разрушенная композиция кузова, кабины и колёс.'),
    ('wreck-roadside', 'Дорожные обломки', 'Цельный кузов с условными повреждениями.', 'Разрушенный кузов, открытый салон и отделённые детали ходовой.'),
    ('house', 'Крыша дома', 'Скаты повёрнуты по неверной оси; планки пересекают кровлю.', 'Замкнутые скаты, общий конёк, фронтоны и согласованные планки.'),
    ('spruce', 'Ель', 'Набор конусов; tree дублирует spruce.', 'Ветви с просветами и свисающие хвойные лапы; один общий ресурс ели.'),
    ('birch', 'Берёза', 'Крупные многогранные комки кроны.', 'Разветвлённая крона с отдельными группами листьев.'),
]


def main():
    after = DATA / 'after/metrics.json'
    metrics = json.loads(after.read_text()) if after.exists() else {}
    shared = []
    for key, title in [('mine', 'Одна мина, три игровых состояния'), ('civilian', 'Civilian: одна модель для pickup и wagon'), ('anti-tank', 'Anti-tank: одна модель для pickup и wagon'), ('fuel', 'Fuel: одна модель для pickup и wagon'), ('shooter', 'Shooter: одна модель для pickup и wagon')]:
        path = f'validation/model-revision/after/{key}-front.png'
        shared.append(f'<figure><figcaption>{escape(title)}</figcaption><a href="{path}"><img src="{path}" alt="{escape(title)}" loading="lazy"></a></figure>')
    rows = []
    for key, title, problem, result in ROWS:
        images = []
        for phase, label in [('before', 'До'), ('after', 'После')]:
            path = f'validation/model-revision/{phase}/{key}-front.png'
            rear = f'validation/model-revision/{phase}/{key}-rear.png'
            exists = (ROOT / 'docs' / path).exists()
            visual = f'<a href="{path}"><img src="{path}" alt="{escape(title)}: {label}" loading="lazy"></a>' if exists else '<p>Снимок ещё не сохранён.</p>'
            images.append(f'<figure><figcaption>{label}</figcaption>{visual}<a href="{rear}">Вид сзади</a></figure>')
        count = metrics.get(key, {}).get('triangles')
        status = f'Отрисовано в Godot. {count:,} треугольников.' if count else 'Проверка новой модели ещё не завершена.'
        rows.append(f'<section id="{key}"><h2>{escape(title)}</h2><p><b>Было:</b> {escape(problem)}<br><b>Изменение:</b> {escape(result)}</p><div class="compare">{"".join(images)}</div><p class="status">{status}</p></section>')
    html = '''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Отчёт по моделям</title>
<style>body{margin:0;background:#20292d;color:#eef1ed;font:16px/1.5 system-ui,sans-serif}main{max-width:1380px;padding:28px;margin:auto}h1{font-size:30px}h2{font-size:23px}p{max-width:1000px}a{color:#bfdbb3}section{padding:22px 0;border-top:1px solid #67716d}.compare{display:grid;grid-template-columns:1fr 1fr;gap:14px}figure{margin:0}figcaption{font-size:18px;margin:8px 0}img{display:block;width:100%;height:auto}.status{color:#b7c7ba}table{border-collapse:collapse;width:100%}td,th{text-align:left;border:1px solid #67716d;padding:10px}@media(max-width:650px){.compare{grid-template-columns:1fr}main{padding:14px}}</style>
<main><p><strong>Историческое сравнение моделей.</strong> Старые деревья и их дальний вариант уже заменены. Это не спецификация текущего проекта и не новый прогон тестов. <a href="PROJECT.md#модели-и-загрузка">Актуальный справочник</a>.</p><h1>Визуальная проверка моделей</h1><p>Реальные снимки из Godot до и после правок в Blender MCP. Одинаковые свет и направления камеры; масштаб подбирается по габаритам модели. Нажатие на снимок открывает полный размер.</p>
<h2>Объединение повторов</h2><table><tr><th>Было</th><th>Стало</th></tr><tr><td>Три одинаковые модели мины</td><td>Одна физическая модель, игровые состояния сохранены.</td></tr><tr><td>Pickup и wagon для каждого сидящего персонажа</td><td>Одна модель на роль; посадочное место отделено от персонажа.</td></tr><tr><td>armor и armor_panels</td><td>Одна геометрия брони, игровые ID сохранены.</td></tr><tr><td>ammo_feed и weapon_parts</td><td>Один ресурс и один экспонат.</td></tr><tr><td>tree и spruce</td><td>Один ресурс ели, один экспонат в галерее.</td></tr><tr><td>Архивные player/evolution/walker/weapon модели, ранние деревья и старые снимки построек</td><td>Удалены из проекта после проверки ссылок.</td></tr></table>
'''+''.join(rows)+'<section><h2>Ель вдали</h2><p>Автоматическое упрощение удаляло крону. Отдельная модель на 1444 треугольника сохраняет ветви. Эти снимки показывают только дальний вариант при одинаковой камере.</p><div class="compare"><figure><figcaption>До</figcaption><img src="validation/model-revision/spruce-lod-before.png" alt="Старая дальняя модель ели" loading="lazy"></figure><figure><figcaption>После</figcaption><img src="validation/model-revision/spruce-lod-after.png" alt="Исправленная дальняя модель ели" loading="lazy"></figure></div></section><section><h2>Общие модели после объединения</h2><p>Один ресурс тела переиспользуется в обоих видах транспорта. Цвет и снаряжение роли остаются отдельными. Скамейка принадлежит пикапу.</p><div class="compare">'+''.join(shared)+'</div></section><section><h2>Общая сцена</h2><p>221 экспонат, пустых моделей нет. Открыть <code>presentation/debug/model_gallery.tscn</code> в Godot и нажать F6. <a href="PROJECT.md#модели-и-загрузка">Управление и состав</a>.</p><a href="validation/model-gallery/npc-map.png"><img src="validation/model-gallery/npc-map.png" alt="Общая сцена моделей" loading="lazy"></a></section><section><h2>Проверки</h2><p>96/96 сценариев с повторными проверками исправлений. <a href="validation/model-revision/verification.json">Результаты и ссылки на логи</a>. Снимки подтверждают вид моделей; замеры при разной нагрузке системы не используются как доказательство ускорения игры.</p></section></main></html>'
    (ROOT / 'docs/model-revision-report.html').write_text(html)
    print('Report:',len(metrics),'captured models')

if __name__ == '__main__': main()
