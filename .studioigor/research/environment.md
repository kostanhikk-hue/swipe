# Environment — research (2026-11-24)
Engine: Godot 4.7.2, GDScript, 2D, Windows. Session: Claude (облако) + Linux-VM на ноутбуке пользователя (device_bash), папка Desktop\swipe смонтирована.

## Findings
- Godot 4.7.2 stable — актуальная стабильная ветка (4.8 в бете). Linux-бинарь ставится в VM без sudo; Windows-версия — архив с godotengine.org, установщика нет.
- GUT 9.7.1 — ветка для Godot 4.7.x (README GUT). CLI: `-s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`, exit 0/1.
- gdtoolkit 4.x (gdlint/gdformat) — `uv tool install "gdtoolkit==4.*"`.
- godot-ai (hi-godot) — лучший MCP редактора; актуальная 4.3.1 (security-релиз), v4 требует Godot 4.7+ и uv; работает только с Claude Code, запущенным на той же машине, что и редактор.
- Coding-Solo/godot-mcp — альтернатива без редактора (npx), тоже локальный stdio.
- Кадры в VM: Xvfb + Mesa (llvmpipe) + `--rendering-driver opengl3` — capture.gd работает в окне Xvfb, проверено.
- Рендерер gl_compatibility: подходит под бюджет «60 fps на встроенной графике».

## What this changes
- Агент водит Godot через CLI в VM: импорт, тесты, CAPTURE, линтер. MCP редактора в этой сессии не подключается (Claude Code на Windows не запущен) — отложено до работы в Claude Code на ПК.
- Пользователь смотрит и играет через Godot 4.7.2 для Windows: `play.bat` в корне проекта.
- Экспорт под Windows (шаблоны 4.7.2) — позже, в фазе релиза/первых сборок.

## Sources
- https://github.com/bitwes/Gut (README, таблица версий)
- https://github.com/hi-godot/godot-ai ; https://store.godotengine.org/asset/dlight/godot-ai/
- https://github.com/godotengine/godot/releases/tag/4.7.2-stable

## Update (same day)
- У пользователя Godot 4.6.2 (Desktop) — проект переведён на 4.6.2, GUT 9.6.1 (ветка для 4.6). Logger есть с 4.5 — capture.gd работает. godot-ai v4 требует 4.7+, для 4.6 — последний v3.
