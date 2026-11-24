# Assets — Реликварий (рабочее название)

<!-- Phase 5 (references/assets.md). -->

## Inventory
<!-- one line per asset card (references/assets.md): name · category · style · budget · source · status -->
| asset | category | style | budget | source | status |
|---|---|---|---|---|---|
| коридор (фон боя) | окружение | радиальный штрих, тёмный проём | 1 экран | код (Engrave) | лук-дев |
| враг «Могильный страж» | персонажи | фронтально, штрих + киноварь глаз | 1 полигон-набор | код | лук-дев |
| рука героя с мечом | персонажи | штрих, низ слева | 1 | код | лук-дев |
| карточка дропа | UI | светлый пергамент, двойная рамка | 1 шаблон | код | лук-дев |
| полосы HP, цифры урона | UI | штриховая рамка, киноварь | — | код | лук-дев |
| шрифт | UI | антиква | 1 | Cormorant Garamond (OFL) | готово |

## Strategy by category
| category | source (pack / Blender / procedural / generation / user) | why | status |
|---|---|---|---|
| окружение | процедурно (код) | решение #11; штрих в духе ART_BIBLE | лук-дев |
| враги и боссы | процедурно → позже рисунки | рисунки — пользователь или публичный домен (Met CC0) | лук-дев |
| предметы (иконки на карточках) | процедурно по типу слота | 10 слотов × силуэт + штрих | план |
| UI и шрифт | код + Cormorant Garamond (OFL) | гравюрная антиква с кириллицей | лук-дев |
| VFX | код: брызги киновари, штрих-вспышки | без свечения (ART_BIBLE) | план |
| звук | CC0-наборы (Kenney/freesound) | нужен браузер для скачивания | план |
| музыка | CC0/CC-BY эмбиент или пользователь | решить к слайсу | план |

## Conventions
Экран 1280×720, stretch canvas_items. Рисунки-замены: PNG, game/art/<категория>/<id>.png, id = id в data/. Цвета только из палитры ART_BIBLE. Процедурные заглушки — scripts/engrave.gd.

## Requests to the user
- none

## License registry
| asset / pack | source (URL) | license | author | path | attribution |
|---|---|---|---|---|---|
| Cormorant Garamond | https://github.com/google/fonts/tree/main/ofl/cormorantgaramond | OFL 1.1 | Christian Thalmann | game/art/fonts/ | в титрах |
| GUT 9.6.1 (только тесты) | https://github.com/bitwes/Gut | MIT | bitwes | game/addons/gut | не в сборке |
