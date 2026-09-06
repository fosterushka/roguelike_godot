# Иконки интерфейса

Сверено 2026-09-06. [industrial-icons.png](industrial-icons.png) создан встроенным GPT Image 6 сентября 2026 года. Прозрачность сохранена. [ui_icons.gd](../../presentation/ui/ui_icons.gd) предоставляет 16 регионов атласа через `texture()`, `apply()` и `view()`; отдельные PNG для каждой иконки не нужны.

Атлас зарегистрирован в [asset_manifest.json](../../data/asset_manifest.json), индексы строк проверяются [ui_icons_test.gd](../../tests/ui_icons_test.gd). Применение в игре: [UI](../../docs/ui.md).

Исходный запрос генерации (сохранён без изменений):

Use case: stylized-concept. Asset type: single production UI icon atlas for an industrial wasteland vehicle game. Generate one square 1024x1024 transparent PNG sprite sheet, exact regular 4 by 4 grid, 16 equal 256x256 cells. Each icon centered in its cell, max 150x150 with generous transparent gutters. Consistent simple bold ivory monochrome stencil silhouettes, tiny muted amber accents, extremely readable at 24 pixels. Flat front-facing graphic symbols, clean edges, no background tiles, no circles surrounding icons, no rounded badges, no bubbles, no lettering, no words, no watermark, no shadows. Exact row-major subjects: row1 crossed rifle and wrench (armory), storage crate (stash), closed safe with wheel (vault), warehouse building (base); row2 two opposing horizontal arrows (trade), right-pointing play triangle (play), gear (settings), simple X (close); row3 medical cross (health), fuel can (fuel), three metal scrap plates (scrap), three cartridges (ammo); row4 wrench (repair), two crew bust silhouettes (crew), clipboard with checkmark (missions), open doorway with outward arrow (extract). Ensure exactly these 16 distinct icons, nothing outside the symbols. Actual transparent alpha background.

Результат генерации имеет размер 1254×1254, несмотря на размер в запросе. Код вычисляет регионы по реальному размеру текстуры, использует целый индекс строки и внутренние поля клетки.
