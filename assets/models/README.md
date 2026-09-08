# Авторские модели Blender

Игровые модели в едином военном low-poly стиле. Редактируемые `.blend`, статические `.obj`, `.mtl` и палитры находятся здесь. Каталог исключён из игрового импорта через `.gdignore`.

| Каталог | Содержимое | Использование в игре |
| --- | --- | --- |
| `player/` | Военный пикап | `assets/vehicles/military_pickup.glb` |
| `wagons/` | Шесть прицепов | `assets/vehicles/military_wagon_*.glb` |
| `equipment/` | Оружие, модули и оборудование | `assets/vehicles/military_equipment.glb` |
| `people/` | Rifleman, AK, bazooka, bomber | `assets/actors/military_people.glb` |
| `enemies/` | Девять видов техники и пять обломков | `assets/actors/military_enemies.glb` |
| `field_props/` | Гарнизон 3, одна мина с runtime-состояниями, припасы и ремонтная машина | `assets/actors/military_field_props.glb` |
| `airdrop/` | Отдельный груз с парашютом | `assets/actors/airdrop.glb` |
| `environment/` | Кусты, трава и цветы | `assets/environment/military_environment.glb` |
| `trees_rebuilt/` | Ель и берёза с однотонной окраской | `assets/environment/textured_trees.glb` |
| `world_quality/` | Дома, wreck, животные, камни, loot и world-prop kit | `assets/environment/world_quality.glb` |

NPC и техника используют общие меши и материалы через существующие пулы. Колёса, роторы, части босса и семь частей пехотного рига сохраняют отдельные узлы для анимации. Статические части построек объединяются внутри исходных групп, поэтому разрушение и механизмы сохраняют своих владельцев. Terrain остаётся процедурным; камни и world props берутся из общего `world_quality` kit.

## Пересборка

Из корня проекта:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/blender/build_player.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/blender/build_people.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/blender/build_military_enemies.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/blender/build_world_assets.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/blender/build_military_environment.py
```

Деревья пересобираются командой `Blender --background --factory-startup --python scripts/blender/build_textured_trees.py`. Общий атлас `tree_atlas.png` имеет размер 32×32 и содержит четыре сплошных цвета без градиентов и узоров; каждый вид использует один меш и один материал. Стволы при генерации стоят вертикально.

`monuments/` не содержит source-моделей для runtime. Это необязательный round-trip export из Godot генераторов `authored_*.gd`, который можно создать для внешней проверки:

```sh
/Users/fosterushka/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/blender/export_monuments.gd
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/blender/convert_monuments.py
```

После изменения игровых GLB и PNG выполните импорт Godot. Проверки: `python3 tests/run_all.py`. Рендеры: `tests/military_world_capture.tscn` и `tests/military_gameplay_capture.tscn`; изображения сохраняются в `docs/validation/military-world/`.

Blender использует Z-up, игровые сцены Godot используют Y-up. OBJ содержит статическую геометрию; храните его вместе с MTL и палитрами. Пересборка перезаписывает сгенерированные файлы, поэтому ручные варианты сохраняйте под отдельными именами.

Актуальные механики, каталог моделей и ограничения старых отчётов: [PROJECT.md](../../docs/PROJECT.md#модели-и-загрузка). Статистика и preview в source-каталогах относятся к соответствующему экспорту; точные текущие размеры проверяйте по stats.json, GLB и runtime-адаптеру.
