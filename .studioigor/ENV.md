# Environment — Реликварий (рабочее название)

<!-- Phase 4 (references/environment.md). Commands verified by a real run.
VERIFIED is switched only by `studio.py verify`. CAPTURE writes images to
.studioigor/captures/. -->
VERIFIED: yes

## Installed
| tool | version | why |
|---|---|---|
| Godot (Linux, VM агента) | 4.6.2 | тесты, импорт, CAPTURE — `$HOME/tools/godot` |
| GUT | 9.6.1 | тесты формул (game/addons/gut) |
| gdtoolkit | 4.x | gdlint / gdformat |
| Xvfb + Mesa | системные | окно для CAPTURE без экрана |
| Godot (Windows, у пользователя) | 4.6.2 | Desktop\Godot_v4.6.2-stable_win64.exe — `play.bat`, `edit.bat` |

## Agent integrations
- Godot CLI в Linux-VM (device_bash) — основной канал агента; проверено импортом, тестами и CAPTURE.
- MCP редактора (godot-ai 4.3.x) — не подключён: в этой сессии нет Claude Code на Windows. Подключить, если работа переедет в Claude Code на ПК.
- LSP: в открытом редакторе; без него ошибки ловятся `--import` и CAPTURE (Logger).

## Commands
RUN: play.bat (Windows: главная сцена = текущий гим, сейчас M03 loop_gym: враг → бой → дроп)
TEST: export PATH=$HOME/.local/bin:$PATH && cd game && godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
BUILD: — (шаблоны экспорта Windows поставим к первой сборке)
CAPTURE: export PATH=$HOME/.local/bin:$PATH && cd game && xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 --script res://tools/capture.gd -- --out ../.studioigor/captures/hello --duration 4 --every 0.5 --inputs tools/inputs_hello.json
EDITOR: edit.bat (на Windows)
BALANCE: export PATH=$HOME/.local/bin:$PATH && cd game && godot --headless --path . -s res://tools/balance_sim.gd -- --runs=200 [--policy=melt] [--set=depth_hp:0.14]

## Pitfalls
- VM: без `--audio-driver Dummy` ALSA сыпет ошибки (безвредно).
- VM: `godot` не в PATH по умолчанию — команды начинаются с export PATH.
- После внешних правок файлов — `godot --headless --path game --import`.
