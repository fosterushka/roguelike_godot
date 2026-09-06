# Генерация мира

Актуализировано по коду 2026-09-06.

Каждый новый рейд и перезапуск получают новый 32-битный seed в `app/main.gd`. `run_seed_override` служит для повторяемых проверок. Мир создаётся целиком в GDScript: Node.js и исходный TypeScript-проект не нужны во время игры. Исходный мир 72841 используется как фон до начала рейда и как источник шаблонов геометрии.

## Модули и порядок сборки

`modules/world/generation/world_generator.gd` создаёт контекст, деревни, леса, руины, траншеи, скалы, кратеры, придорожные объекты, достопримечательности и внешнее окружение. В конце `vegetation_generator.gd` добавляет новые рощи. `arena.rebuild_from_context()` заменяет представление и коллизии; Main сбрасывает бой и перепривязывает runtime мира к тому же seed под экраном загрузки.

| Код | Ответственность |
| --- | --- |
| `generation_context.gd` | Seed, RNG, пулы, регистрация объектов и семантических данных |
| `layout_generator.gd` | Дороги, поселения и области размещения |
| `authored_props.gd`, `authored_monuments.gd` | Дома, промышленность, животные, декорации и их иерархия |
| `natural_props.gd`, `rock_formations.gd` | Природные объекты и разрушаемые скальные секции |
| `battlefield_features.gd`, `scatter_generator.gd` | Крупные области и заполнение окружения |
| `presentation/world/generated_world_view.gd` | Отрисовка подготовленного контекста |
| `presentation/world/road_view.gd`, `road.gdshader` | Лента дороги, стыки и мягкие края |

## Контракты генерации

Контекст хранит `layout`, `props`, `villages`, `activity_blockers`, `landmarks`, `rock_obstacles`, `groups` и данные анимации. `append()` добавляет экземпляр в ограниченный пул, `register_prop()` сохраняет ID, здоровье, награду и ссылки на визуальные части. Фабрики получают общий контекст через `setup(context, natural)`.

Для перенесённых фабрик важен порядок вызовов RNG, включая неиспользуемые исторические выборки. Координаты игровых записей сохраняются отдельно от float32-трансформаций Godot. Каталог `world_primitive_catalog.gd` повторно использует экспортированные примитивы; исходный sphere helper использовал IcosahedronGeometry, поэтому произвольная замена на SphereMesh меняет геометрию.

Текущая игра намеренно отличается от старого мира: добавлены рощи, заменены деревья и скалы, убраны декоративные люди. Полное визуальное равенство исходной игре не является подтверждённым результатом. Подробности: [природа](natural-world.md), [поведение мира](world-gameplay-parity.md).

## Проверки

`world_generation_test.gd`, `natural_props_test.gd`, `authored_props_test.gd` и `world_builder_test.gd` сравнивают перенесённые данные с fixtures. `composed_world_seed_test.gd` и `world_rebuild_test.gd` проверяют сборку, сброс и согласованность объектов. Файлы находятся в `tests/`.

`tests/build_source_reference.mjs` создаёт эталон исходной Three.js-сцены при наличии исходного checkout. `tests/render_reference.gd` создаёт кадр Godot для отдельного сравнения. Headless не проверяет изображение и GPU-время. Команды и границы проверки: [testing.md](testing.md).
