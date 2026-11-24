# Technology — Реликварий (рабочее название)

<!-- Phase 3 (references/stack.md). ENGINE — one of: godot, godot-mono, unity,
unreal, web, defold, bevy (read by studio.py and envcheck.py). DIMENSION — 2D or 3D
(2.5D with 3D models is 3D); envcheck.py recommends Blender for 3D. -->
ENGINE: godot
ENGINE VERSION: 4.6.2 (как у пользователя на ПК; переход на 4.7+ — решением пользователя)
DIMENSION: 2D
LANGUAGE: GDScript
PLATFORMS: Windows (ПК), Steam позже

## Decision
- context: автобой-рогалик от первого лица, статичная камера, 2D-гравюры врагов и предметов, карточки-свайпы, много цифр и данных; ПК; разработчик на Windows
- options: Godot 4.7 — бесплатно, текстовые сцены, MCP, экспорт из CLI / минус: кадры только с окном; Веб + Electron/Tauri — самый быстрый цикл, игра по ссылке / минус: обёртка и Steamworks через сторонние модули; Unity 6 — экосистема / минус: вход, лицензия, хуже водится агентом
- choice and why: Godot 4.6.2 (была 4.7 — сменили под установленную у пользователя), GDScript, 2D — выбор пользователя; агент водит его полностью, у пользователя уже есть Godot-проект
- consequences: графика — 2D-гравюры (PNG); сначала заглушки, нарисованные кодом (процедурный штрих), потом замена на настоящие рисунки без изменения кода (решение пользователя); предметы, свойства, враги — в файлах данных (.tres/.json)

## Budgets
60 fps на любом ПК со встроенной графикой; загрузка < 3 с; сборка < 150 МБ; один бой не дольше 10 с при скорости x1

## Project structure
game/ — проект Godot: scenes/, scripts/, data/ (предметы, свойства, теги, враги), art/ (заглушки и рисунки), tests/ (только формулы боя и экономики)
