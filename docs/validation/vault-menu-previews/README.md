# Vault, menu and model-preview capture

Графический прогон выполнен на Godot 4.7.2, Forward+ / Metal, Apple M4 Pro. Лог: [render.log](render.log).

Сценарий `compact_ui_capture.tscn` сохранил 62 кадров со статусом PNG `0`: EN/RU, 960×600 и 1280×800, главное меню, Singleplayer, Options, вкладки Vault, торговцы, hover-preview, пауза и HUD. Это результат конкретного рендера, а не полный игровой smoke-тест.

Отдельный финальный захват [resize-render.log](resize-render.log) после последней подгонки камеры сохранил ещё три PNG со статусом `0`: M4, bumper и pickup. В этом логе нет ошибок движка.

В этой папке сохранена отобранная проверяемая выборка:

- [main-en-960.png](main-en-960.png), [singleplayer-en-960.png](singleplayer-en-960.png)
- [options-main-ru-960.png](options-main-ru-960.png), [options-pause-ru-960.png](options-pause-ru-960.png), [pause-ru-960.png](pause-ru-960.png)
- [vault-en-960.png](vault-en-960.png), [armory-hover-en-1280.png](armory-hover-en-1280.png)
- [mechanic-ru-960.png](mechanic-ru-960.png), [quartermaster-ru-960.png](quartermaster-ru-960.png), [scavenger-ru-960.png](scavenger-ru-960.png)
- [item-preview-m4.png](item-preview-m4.png), [item-preview-bumper.png](item-preview-bumper.png), [item-preview-pickup.png](item-preview-pickup.png)

Кадр Armory hover получен реальным `InputEventMouseMotion` над `Inspect`; harness требует, чтобы `item_preview_pip.visible` стал `true`. Последний захват отдельно проверяет консервативные поля камеры для миниатюры 58×52 и PIP 310×186. Карточки торговцев выбираются настоящим кликом по `trader_id` и повторно ищутся после перестройки панели.

Портреты находятся в [assets/ui/traders](../../../assets/ui/traders/README.md). Они созданы для текущего UI и не содержат текста, значков или bubble-элементов.

## Headless validation

[full-suite.json](full-suite.json) фиксирует один полный прогон: 86 из 87 скриптов завершились чисто. Единственный `expedition_flow_test.gd` завершился по таймауту 90 секунд, потому что в процессе был загружен старый сценарий с действием `start`.

[final-check.json](final-check.json) содержит повтор после исправления: `expedition_flow_test.gd` и `item_preview_test.gd` завершились чисто. Поэтому для всех 87 скриптов manifest есть успешное доказательство, но это не один непрерывный прогон 87/87.

Ограничение: эти кадры подтверждают композицию и видимость в указанном рендере. Они не подтверждают производительность, звук или длительный игровой сеанс.
