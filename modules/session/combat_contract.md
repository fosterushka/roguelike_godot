# Контракт боевого runtime

Сверено с кодом 2026-09-06. `modules/combat/combat_runtime.gd` является `Node3D` с `PROCESS_MODE_PAUSABLE`. Добавьте узел в дерево до `setup(vehicle)`. Симуляция идёт только при `model.running` и положительном игровом delta.

## Публичный API

- `setup(vehicle)`, `reset_run(seed_value = 72841)`: подключение машины и сброс заезда.
- `set_running(bool)`: переключение симуляции и движения. Остановка очищает помехи и прогресс взлома; терминальный заезд возобновить нельзя.
- `get_state()`: снимок модели; вложенные игровые массивы копируются.
- `focus_next()`, `focus_target(id)`, `focus_at(world_position)`: выбор цели, включая доступные части босса.
- `activate_ability(slot)`: 0 Nitro, 1 Ram, 2 Repair; возвращает принятие действия.
- `buy_upgrade(id)`: делегирование progression с синхронизацией машины.
- `install_weapon(type)`: низкоуровневое добавление; UI должен использовать progression для цены и правил сборки.
- `apply_player_stats(stats)`: обновляет только существующие поля игрока.
- `finish_run(won, reason = "")`: завершает модель один раз; `extracted` создаёт терминальный статус эвакуации.
- `deliver_result(event)`: выдаёт отложенный результат только для текущего поколения и только один раз.

Runtime публикует `state_changed(data)` и `combat_event(event)`. Обработчик `result_deferred` может отложить доставку результата, например до окончания сцены гибели. Поэтому завершение модели и показ результата не обязаны совпадать по времени.

## Данные и границы

Снимок включает поколение, волну, статус, время, угрозу, радиус, очередь, ресурсы, здоровье, XP, `player`, `weapons`, `enemies`, `boss_components`, `projectiles`, `pickups`, `mines`, `hack_status`, `salvage_charge` и `focus_id`. Точная форма: `CombatModel.snapshot()`.

Событие определяется полем `kind`, содержит `generation` и поля конкретного действия. Результат содержит `won`, `reason`, `extracted`, `wave`, `kills`, `elapsed`. Не редактируйте внутреннюю очередь для изменения результата.

`player.active_protocols`, `selected_sidegrades`, `treasury_count` принадлежат интеграции progression/combat. Runtime синхронизирует позицию, скорость, курс, скольжение, здоровье, топливо и ввод взаимодействия с реальной машиной.

Дрон хранит позицию в плоскости земли, высоту отдельно в `height`. Корпус Левиафана не является поражаемой целью; пять частей имеют собственные ID, HP и фазу доступности. Уничтожение ядра завершает босса, отдельные части не выдают награду за целого врага.

Мины: сторона `enemy`/`friendly`, вооружение, время жизни и прогресс взлома. `hack_status` передаёт доступность, требование модуля, текущую активность, прогресс и ID; потребители должны использовать значения по умолчанию для необязательных полей.

## Подключение мира

`model.spawn_enemy(kind, position, options)` применяет лимиты и фабрику. Для мирового врага задавайте `counts_toward_wave=false`; `activity_route_controlled=true` передаёт движение внешнему маршруту.

Callbacks модели: `world_collision_query`, `enemy_motion_query`, `enemy_steering_query`, `weapon_origin_query`, `spawn_validity_query`, `spawn_visibility_query`, `friendly_targets_query`, `friendly_damage_query`, `enemy_target_query`. Запрос видимости спавна возвращает true вне камеры. Запрос столкновения с миром может изменить позицию выстрела до точки контакта; отрезок предварительно ограничивается следующим попаданием в сущность.

`clock_delta` задаёт игровой шаг runtime, `support_step` обновляет поддержку перед боевой моделью. Порядок времени и отложенного результата описан в [session-flow-parity.md](../../docs/session-flow-parity.md).

Проверки: `tests/combat_test.gd`, `advanced_combat_test.gd`, `enemy_ai_test.gd`, `session_flow_test.gd`. Это описание интерфейса по коду, не отчёт о новом прогоне или визуальном совпадении.
