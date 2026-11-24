# Stack — research (2026-11-24)
Game: рогалик с автобоем, вид от первого лица, статичная камера, враг по центру, карточки-свайпы; стиль — гравюра (штриховка) на пергаменте. Платформа: ПК (Steam позже). Разработчик на Windows.

## Findings
- Godot: последняя стабильная — 4.7.2 (18.08.2026); 4.8 beta 4 вышла 18.11.2026 (возможно последняя бета). MIT, без роялти.
- Godot + Claude Code: несколько живых MCP — Coding-Solo/godot-mcp (`claude mcp add godot -- npx @coding-solo/godot-mcp`), godot-ai, godot-mcp-enhanced (данные на 06–08.2026).
- Штриховка в Godot: готовые spatial-шейдеры hatching/cross-hatching и Moebius-outline на godotshaders.com; техника light shader + 3-канальная текстура штриха (hexaquo.at). Значит, гравюрный 3D-рендер реалистичен на Godot 4.
- Steam: Steam Direct — $100 за игру, возвращается после $1000 выручки; комиссия 30%; проверка 1–5 дней + минимальные сроки до первого релиза.
- Web-стек (Three/Pixi + Electron/Tauri для Steam): самый удобный для агента (Playwright, сборка за секунды), но для Steam нужна обёртка и Steamworks-интеграция через сторонние модули — UNVERIFIED актуальность.
- Unity 6: нужен вход и лицензия, YAML-сцены редактируются через редактор; для 2D/2.5D-интерфейсной игры избыточен.
- У пользователя на компьютере уже есть Godot-проект (~/game: .godot, scenes, scripts) — Godot, вероятно, установлен и знаком.

## What this changes
- Рекомендация — Godot 4.7 (стабильная ветка; 4.8 — после релиза): ПК-экспорт из CLI, текстовые сцены, MCP, штриховка шейдером.
- Unreal исключён (агент плохо водит, 40+ ГБ); Unity — только если важен опыт пользователя в нём.

## Sources
- https://godotengine.org/blog/release (2026)
- https://www.linuxcompatible.org/story/godot-48-beta-4-released-as-likely-final-beta-before-stable-launch/ (18.11.2026)
- https://gamedev.net/news/5172-godot-engine-472-stable-released/ (08.2026)
- https://mcpservers.org/servers/Coding-Solo/godot-mcp
- https://godotshaders.com/shader-tag/hatching/ ; https://hexaquo.at/pages/handpainted-light-shader-cross-hatching-in-godot/
- https://partner.steamgames.com/steamdirect
