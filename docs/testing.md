# Проверки и экспорт

Процедура сверена с [tests/run_all.py](../tests/run_all.py) и [export_presets.cfg](../export_presets.cfg) 2026-09-08. Само обновление документации не является новым прогоном игры. Описание систем: [PROJECT.md](PROJECT.md).

## Логика и интеграция

Из корня проекта, подставив путь к установленному Godot:

```sh
python3 tests/run_all.py --godot /path/to/Godot
python3 tests/run_all.py --godot /path/to/Godot --only offline_session_test.gd session_flow_test.gd
python3 tests/run_all.py --godot /path/to/Godot --only vehicle_airborne_test.gd --output /tmp/iron-airborne-check
```

`GODOT_BIN` заменяет `--godot`. Без обоих runner ищет приложение в /Applications, затем ~/Downloads. `--timeout` ограничивает каждый сценарий, `--output` задаёт каталог отчёта и логов; без него создаётся уникальная временная папка.

Runner содержит явный TESTS, а не автоматический поиск всех .gd. Перед любым запуском, включая `--only`, он проверяет дубликаты, отсутствующие файлы и все `*_test.gd`: такой файл обязан быть в TESTS. Добавляя обязательный тест, зарегистрируйте его там. Узнать текущий список и допустимые параметры можно через `python3 tests/run_all.py --help`; число зарегистрированных файлов не является числом успешных проверок.

Скрипт в `tests/` вне TESTS должен быть только helper: capture/host/scene/sheets с именем `*_(capture|host|scene|sheets).gd`, либо одним из явно перечисленных `render_benchmark.gd`, `render_reference.gd`, `verify_pack.gd`. Единственный render-only тест вне manifest — `spatial_batches_render_test.gd`: он перечислен с причиной в `EXCLUDED_RENDER_TESTS` в guard, потому что требует GPU. Это исключения для ручного рендера и подготовки, а не headless-проверки. `tests/architecture_guard.py` также запрещает новые зависимости `modules/` от `presentation/` и `app/`; прежние связи разрешены только по конкретному source-to-target edge с причиной в этом файле.

Успех требует одновременно кода выхода 0, распознанной итоговой строки и отсутствия ошибок движка, скриптов, assert и сообщений об утечках в stdout и engine log. Не ослабляйте фильтр ради зелёного отчёта. После импорта/замены ассетов сначала выполните:

```sh
godot --headless --path . --editor --import --quit
```

## Какие сценарии выбирать

Имена ниже относятся к папке [tests](../tests), передаются в `--only`. Это карта существующих сценариев, не заявление об их текущем прохождении.

| Изменение | Профильные сценарии |
| --- | --- |
| Ввод, пауза, результат | offline_session_test.gd, session_flow_test.gd, run_clock_test.gd, world_result_test.gd |
| Машина, подвеска, прыжки | vehicle_motion_test.gd, vehicle_response_test.gd, wheel_vehicle_test.gd, vehicle_airborne_test.gd, vehicle_render_runtime_test.gd |
| Дорога, следы, топливо | road_speed_test.gd, tire_trails_test.gd, fuel_station_test.gd, handling_wildlife_test.gd |
| Бой, враги, волны | combat_test.gd, advanced_combat_test.gd, enemy_ai_test.gd, enemy_factory_test.gd, support_wave_test.gd |
| Помехи, мины | jammer_gameplay_test.gd, jammer_feedback_test.gd, mine_hacking_module_test.gd |
| Модули, уровни, радар, комбо | progression_test.gd, combat_upgrade_test.gd, radar_progression_test.gd, radar_armory_test.gd, combo_rewards_test.gd |
| Состав и оборудование | caravan_loadout_test.gd, caravan_combat_test.gd, caravan_formation_test.gd, caravan_integration_test.gd, armory_unit_test.gd |
| Экипаж, встречи, посадка | crew_runtime_test.gd, crew_encounter_test.gd, crew_seating_test.gd, caravan_crew_test.gd |
| Груз, экономика, кейсы | raid_loot_test.gd, meta_economy_test.gd, expedition_flow_test.gd, case_rewards_test.gd, case_opening_test.gd |
| Миссии | mission_catalog_test.gd, mission_tracker_test.gd, mission_flow_test.gd, mission_board_test.gd, crew_missions_test.gd |
| Эвакуация | extraction_defense_test.gd, extraction_zone_flow_test.gd, world_activities_test.gd |
| Мир, seed, коллизии | world_generation_test.gd, world_builder_test.gd, composed_world_seed_test.gd, world_rebuild_test.gd, base_collision_test.gd |
| Разрушение, погода, торнадо | world_gameplay_test.gd, village_destruction_test.gd, tornado_interaction_test.gd, weather_transition_test.gd |
| Пулы, terrain, загрузка | spatial_batches_test.gd, terrain_chunks_test.gd, model_dedup_test.gd, environment_lod_test.gd, loading_test.gd |
| UI, язык, превью | hud_layout_test.gd, ui_menu_regression_test.gd, ui_language_flow_test.gd, item_preview_test.gd, trailer_ui_test.gd |
| Сборка всего рейда | integration_test.gd, full_run_test.gd, combat_soak_test.gd |

Профильные тесты запускайте после локального изменения; полный manifest нужен при изменении общих контрактов и широкой интеграции. Тесты сохранения должны использовать уникальный временный профиль. Не подставляйте реальный пользовательский профиль в capture или тест.

## Настоящий рендер

Headless не подтверждает внешний вид, GPU-прогрев, отсутствие первого зависания, звук или удобство управления. Название `visual_smoke` тоже не превращает headless в графический запуск.

Примеры запуска с графическим Godot:

```sh
godot --path . res://tests/compact_ui_capture.tscn
godot --path . --script res://tests/vehicle_terrain_capture.gd
godot --path . --script res://tests/fuel_station_capture.gd
```

Перед запуском прочитайте выбранный capture-скрипт: он задаёт подготовленный seed, сцену, временный профиль и output-путь. Для предметов, дождя и встречи с NPC есть `raid_loot_capture.gd`, `rain_coverage_capture.gd`, `crew_encounter_capture.gd`. Для ручной диагностики доступны `presentation/debug/model_gallery.tscn` и `presentation/debug/vehicle_playground.tscn`.

Просмотрите полученные кадры, проверьте engine log и подпишите точный сценарий. Для UI нужны EN/RU и узкое окно; для автомобиля движение, остановка, склон, прыжок и восстановление после приземления. Подготовленная сцена не заменяет ручной рейд.

## Производительность и артефакты

[ARTIFACTS.md](ARTIFACTS.md) отделяет прошлые результаты от текущей реализации. [PERFORMANCE_REPORT.md](PERFORMANCE_REPORT.md) и [performance-measurements.json](performance-measurements.json) описывают исторический статический маршрут; не используйте их числа как текущий FPS.

Новые измерения фиксируют commit и локальные изменения, движок, renderer, устройство, разрешение, seed, маршрут, VSync/лимит FPS, холодный/прогретый кеш и длительность. Графические замеры запускаются последовательно без конкурирующих Godot-процессов. Отдельно учитываются первая загрузка, первый вид/выстрел, устойчивые кадры и память. Headless soak, статическая камера и полный игровой рейд являются разными проверками.

## macOS export

Preset `macOS Offline` собирает universal-пакет; подпись и notarization отключены, JSON включены, tests/docs/build/override.cfg исключены. Сначала проверьте соответствующие установленному движку export templates. Их прежнее отсутствие или наличие не описывает другое окружение.

```sh
mkdir -p build
godot --headless --path . --export-release "macOS Offline" build/iron-caravan-macos.zip
```

Проверьте содержимое архива, затем самостоятельно запустите приложение из распакованного пакета без сети: меню, рейд, ассеты, звук, сохранение и повторное открытие. `tests/verify_pack.gd` предназначен для дополнительной проверки pack; запуск PCK установленным Godot не равен запуску самостоятельного приложения. Команды выше являются процедурой, а не утверждением, что артефакт уже собран.
