# Реестр качества моделей

Дата: 7 сентября 2026. [Визуальный отчёт до/после](model-revision-report.html). Это реестр фактических путей в рантайме, а не обещание, что каждый OBJ из архива был переделан.

## Что было незакрыто в начале

| Семейство | Проблема | Статус сейчас |
| --- | --- | --- |
| Игрок и вагоны | Старые source-меши были в каталоге рядом с игровыми путями. | Активны отдельные Blender GLB. |
| Враги и люди | Source-модели были недостаточно детальными. | Активна общая Blender-библиотека актёров. |
| Оборудование | Сборка из простых форм и старые source-варианты. | Активна Blender-библиотека оборудования. |
| Лут, снаряды, полевые предметы | Часть путей брала legacy geometry. | Активен `world_quality.glb` и `military_field_props.glb`. |
| Мир | Камни, заборы, мёртвые деревья, мелкая растительность и часть props были raw или процедурными. | Основные instanced-пулы и одиночные props переведены в Blender kit. |
| Landmark-объекты | Базы крупных сооружений строились из примитивов. | Конструкционные пулы и детали перенесены в Blender kit. |

## Активные production-модели

| Семейство | Blender-источник | Runtime-asset и адаптер |
| --- | --- | --- |
| Пикап игрока | `assets/models/player/player.blend` | `assets/vehicles/military_pickup.glb` → `presentation/vehicles/military_pickup.gd` → `wheeled_rig.gd` |
| Шесть вагонов | `assets/models/wagons/wagon_*.blend` | `assets/vehicles/military_wagon_*.glb` → `presentation/vehicles/military_wagon.gd` |
| Оборудование | `assets/models/equipment/equipment.blend` | `assets/vehicles/military_equipment.glb` → `presentation/vehicles/equipment_model.gd` |
| Враги и wreck-варианты | `assets/models/enemies/military_enemies.blend` | `assets/actors/military_enemies.glb` → `presentation/combat/military_enemies.gd` |
| Пехота и экипаж | `assets/models/people/military_people.blend` | `assets/actors/military_people.glb` → `presentation/combat/military_people.gd` |
| Мины, airdrop, heal cart, pickup fuel/salvage, гарнизоны | `assets/models/field_props/field_props.blend`, `assets/models/airdrop/airdrop.blend` | `assets/actors/military_field_props.glb`, `assets/actors/airdrop.glb` → `presentation/combat/military_field_props.gd`, `presentation/world/airdrop_model.gd` |
| Живые деревья | `assets/models/trees_rebuilt/textured_trees.blend` | `assets/environment/textured_trees.glb` → `environment_library.gd`, `tree_meshes.gd` |
| Базовая растительность | `assets/models/environment/military_environment.blend` | `assets/environment/military_environment.glb` → `environment_library.gd` |
| World quality kit | `assets/models/world_quality/world_quality.blend` | `assets/environment/world_quality.glb` → `presentation/world/world_quality_models.gd` |

`world_quality.glb` в активном коде покрывает: овцу, дом, колодец, рынок, utility pole, wreck, scrap, satellite dish, windmill и его blades, pumpjack arm, детали landmark-объектов, бочки, ящики, баки, 6 крупных rocks, два размера boulder, fence post/rail, dead tree, bunker/barracks, пять предметов лута и восемь player/enemy projectile-вариантов. Также в нём находятся scrub, dead brush, grass, flowers, а также `iron/metal/wood/red/earth/ruin/scarStructure` и `cliffFaces/cliffStrata`. Их меши кэшируются и используются общими MultiMesh-пулами через `natural_meshes.gd`; для одиночных props применяется `world_quality_models.gd`.

## Геометрия и совмещение с игровыми правилами

- Rocks из kit имеют радиус не больше `1` в XZ и высоту `Y [0, 1]`. Масштаб `rockMass*`, `rockInstances` и `stoneInstances` поэтому остаётся совместимым с текущими radius/height и круглыми коллизиями.
- Для `barrelInstances`, `crateInstances`, `tankInstances`, fence и девяти construction/cliff pools Blender export нормализует AABB к исходному `world_72841` mesh. В частности, исходный rail имеет ширину `1.8`, а post высоту `1.15`; нельзя оценивать их placement по ранней unit-версии kit. Сохраняются текущие transforms из `natural_props.gd`.
- `deadTrees` — отдельный пул. `tree_replacements.gd` больше не заменяет сухое дерево уменьшенной живой елью или берёзой.
- Каждый kit root имеет один surface и общий материал. Подмена существующего MultiMesh-пула сохраняет один batch; сухие деревья используют отдельный пул. Одиночные props заменяют несколько примитивов одним shared mesh.

## Что ещё не сделано

Выявленные в аудите игровые семейства заменены или детализированы через Blender. Список ниже отделяет сохранённую техническую геометрию и архив от этих замен.

Техническая геометрия остаётся намеренно процедурной: terrain mesh, trenches, bowls, rims, decals, char и transient FX. Это формы поверхности и эффектов, а не standalone props/транспорт/персонажи.

`world_72841` остаётся source-контейнером для совместимости, индексов, terrain data и галереи. В арене и generated world его заменяемые visual pools теперь получают Blender meshes; наличие JSON/OBJ source не означает активный raw production-model.

### Удалённые архивные данные

Удалены JSON-экспорты `player`, `walker_trailer`, `evolution_2..4`, `weapon_*` и три старых состояния мин, ранние standalone-деревья, reference-runtime, `pickup.zip` и Blender backup-файлы `.blend1`. Игрок, вагоны и оборудование используют активные Blender GLB; мина имеет один `FIELD_mine` mesh, `armor_panels` использует canonical `armor`, а enemy/friendly/unarmed остаются только состояниями рантайма. `world_72841`, `world_primitives` и FX сохранены, потому что это данные активного мира и эффектов.

### Не standalone production-модели по назначению

`world_primitives`, construction pools, `fx_sphere`, `fx_chunk`, `fx_gear`, `fx_collapse_gear`, `fx_masonry`, `fx_shockwave`, `fx_cylinder*`, `fx_cone*` — служебная процедурная геометрия для сооружений, разрушения и transient FX. Их не надо учитывать как персонажей, транспорт или готовые props. Переделывать их стоит только вместе с задачей на конкретный визуальный эффект или полную замену construction system.

`weapon_parts` сейчас осознанно показывает модель `ammo_feed` из Blender equipment library; отдельного loot root для него пока нет.

## Проверка

Текущая галерея: 221 экспонат, пустых моделей нет. Архивные версии и одинаковые превью удалены.

96/96 сценариев покрыты полным прогоном и повторными проверками исправлений.
Первый полный прогон: 94/96. Исправлены положение корней и обход вложенной модели
игрока в smoke-тесте. Повторные проверки включают окончательные ресурсы деревьев,
объединение моделей, галерею, мир и LOD. Точный состав и логи:
[verification.json](validation/model-revision/verification.json).

Визуально просмотрены 18 моделей в Godot Metal и обновлённая общая сцена.
[Сравнение до/после](model-revision-report.html) содержит снимки спереди и сзади.
Ель использует вручную созданный дальний вариант на 1444 треугольника,
поскольку автоматическое упрощение удаляло крону. Ближний вариант имеет 3724.

Замеры одного статического ракурса мира сохранены в `validation/model-revision`.
На них влияли параллельные приложения и фокус окна, поэтому они не подтверждают
ускорение игры или стабильный FPS в бою.
