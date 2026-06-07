# Рекомендуемые моды (NeoForge 1.21.1)

Серверные моды для стабильного TPS при 10–18 игроках с **Create Aeronautics**.
Скачивайте только версии для **Minecraft 1.21.1** и **NeoForge** с [Modrinth](https://modrinth.com) или [CurseForge](https://www.curseforge.com).

---

## Обязательные моды контента (Create Aeronautics)

| Мод | Назначение | Modrinth |
|-----|------------|----------|
| **Create** | Базовый мод Create (NeoForge) | [create](https://modrinth.com/mod/create) |
| **Sable** | Физическая библиотека — **обязательная зависимость** Create Aeronautics | [sable](https://modrinth.com/mod/sable) |
| **Create Aeronautics** | Дирижабли, корабли, физика полёта | [create-aeronautics](https://modrinth.com/mod/create-aeronautics) |

> Без **Sable** Create Aeronautics не запустится. Установите все три мода **одной версии MC (1.21.1)** и проверьте совместимость на странице мода.

---

## Моды оптимизации (обязательно для сервера)

| Мод | Назначение | Modrinth |
|-----|------------|----------|
| **Lithium** | Оптимизация AI, физики, редстоуна, hopper'ов | [lithium](https://modrinth.com/mod/lithium) |
| **FerriteCore** | Снижает потребление RAM | [ferrite-core](https://modrinth.com/mod/ferrite-core) |
| **ModernFix** | Быстрый старт, меньше лагов от NBT и chunk loading | [modernfix](https://modrinth.com/mod/modernfix) |
| **Chunky** | Предгенерация чанков (см. инструкцию ниже) | [chunky](https://modrinth.com/plugin/chunky) |

### Дополнительно (рекомендуется)

| Мод | Назначение |
|-----|------------|
| **Clumps** | Группирует XP-orb'ы → меньше entity lag |
| **AI Improvements** | Оптимизация mob AI на сервере |

---

## Установка

1. Скачайте `.jar` для **1.21.1 / NeoForge**.
2. Положите в папку `mods/` репозитория.
3. **Не добавляйте клиентские моды** (шейдеры, Iris, OptiFine и т.п.) — только серверные.
4. Перезапустите `./start.sh`.

### Минимальный набор в `mods/`:

```
mods/
├── create-<version>.jar
├── sable-<version>.jar
├── create-aeronautics-<version>.jar
├── lithium-neoforge-<version>.jar
├── ferritecore-<version>-neoforge.jar
├── modernfix-neoforge-<version>.jar
└── chunky-<version>.jar
```

---

## Предгенерация чанков через Chunky

Create Aeronautics = полёты на кораблях = загрузка **сотен новых чанков**. Без предгенерации TPS упадёт до 5–10.

### Шаг 1 — Запустите сервер

```bash
./start.sh
```

Дождитесь строки `Done (...s)! For help, type "help"`.

### Шаг 2 — Выберите центр и радиус

В **консоли сервера** (не в игре):

```
chunky center 0 0
chunky radius 8000
```

Для полётов на 10 000+ блоков — радиус **12000+**.

### Шаг 3 — Запустите генерацию

```
chunky start
chunky progress
```

На 2 ядрах / 8 GB RAM радиус 8000 займёт **несколько часов**. Делается один раз.

### Шаг 4 — Пауза и возобновление

```
chunky pause
chunky continue
chunky cancel
```

Chunky **сохраняет прогресс** между перезапусками.

### Шаг 5 — Проверка

```
chunky borders
```

При **100%** в `chunky progress` — мир готов к полётам.

---

## Рекомендуемые настройки server.properties

После первого запуска отредактируйте `server.properties`:

```properties
view-distance=8
simulation-distance=6
max-players=18
spawn-protection=0
```

- `view-distance=8` — баланс качества и нагрузки на 8 GB RAM.
- `simulation-distance=6` — меньше tick-нагрузки за пределами видимости.

---

## Совместимость версий

| Компонент | Версия |
|-----------|--------|
| Minecraft | **1.21.1** |
| NeoForge | **21.1.x** (по умолчанию 21.1.218) |
| Java | **21** |
| Create Aeronautics | **1.0.3+mc1.21.1** или новее |

Перед обновлением любого мода — **сделайте бэкап мира** (`/stop` → дождитесь git push).
