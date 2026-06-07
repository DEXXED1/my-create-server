# Minecraft Server — Create Aeronautics (NeoForge 1.21.1)

Бесплатный модовый сервер Minecraft для 10–18 игроков, разворачиваемый в **GitHub Codespaces** (2 CPU / 8 GB RAM).

- **Версия:** Minecraft Java **1.21.1** + **NeoForge 21.1.218**
- **Мод:** Create Aeronautics (+ Create, **Sable**)
- **Java:** **21** (строго)
- **Туннель:** [playit.gg](https://playit.gg)
- **Синхронизация мира:** Git (ветка `main`)

---

## Быстрый старт

1. Форкните или клонируйте репозиторий.
2. Откройте в **GitHub Codespaces** (Code → Codespaces → Create codespace).
3. Положите моды в `mods/` — см. `RECOMMENDED_OPTIMIZATION_MODS.md`:
   - **Create**, **Sable**, **Create Aeronautics**
   - Lithium, FerriteCore, ModernFix, Chunky
4. Настройте секреты (см. ниже).
5. Запустите:

```bash
chmod +x start.sh
./start.sh
```

6. Адрес для игроков — в `logs/playit.log` или на [playit.gg](https://playit.gg).

---

## Как работает NeoForge

NeoForge **не запускается** через `java -jar server.jar`. Скрипт `start.sh`:

1. Скачивает инсталлятор `neoforge-21.1.218-installer.jar`
2. Запускает `java -jar ... --installServer` → создаёт `libraries/`, `run.sh`, `unix_args.txt`
3. Записывает Aikar's Flags в `user_jvm_args.txt`
4. Стартует сервер:

```bash
java @user_jvm_args.txt @libraries/net/neoforged/neoforge/21.1.218/unix_args.txt nogui
```

---

## Настройка секретов в Codespaces

### 1. GITHUB_PAT — push мира с донорских аккаунтов

1. **Главный аккаунт** → Settings → Developer settings → Personal access tokens.
2. Создайте токен: **Contents → Read and write** для вашего репозитория.
3. Репозиторий → **Settings → Secrets and variables → Codespaces** → New secret:
   - Name: `GITHUB_PAT`
   - Value: `ghp_xxxxxxxx`

Или в терминале Codespace:

```bash
export GITHUB_PAT="ghp_xxxxxxxx"
./start.sh
```

### 2. PLAYIT_SECRET — постоянный IP

1. [playit.gg/account/agents](https://playit.gg/account/agents) → Add Agent → скопируйте Secret Key.
2. Настройте туннель **Minecraft Java** → порт `25565`.
3. Codespaces secret: `PLAYIT_SECRET` = ваш ключ.

---

## Схема «фермы» аккаунтов

```
Аккаунт A/B/C (Codespace) → git pull world/ → ./start.sh → playit → игроки
                                    ↑
                              git push world/ (после /stop)
```

---

## Структура репозитория

```
.
├── start.sh
├── README.md
├── RECOMMENDED_OPTIMIZATION_MODS.md
├── mods/              ← .jar моды (коммитятся)
├── config/            ← конфиги модов
├── world/             ← мир (синхронизируется через Git)
├── logs/              ← логи (gitignore)
├── libraries/         ← NeoForge libs (gitignore, создаётся автоматически)
└── bin/               ← playit (gitignore)
```

---

## Переменные окружения

| Переменная          | По умолчанию  | Описание                        |
|---------------------|---------------|---------------------------------|
| `GITHUB_PAT`        | —             | PAT для git push мира           |
| `PLAYIT_SECRET`     | —             | Secret key playit.gg            |
| `NEOFORGE_VERSION`  | `21.1.218`    | Версия NeoForge для MC 1.21.1   |
| `MC_VERSION`        | `1.21.1`      | Версия Minecraft                |
| `JAVA_MAX_HEAP`     | `6500M`       | Максимум RAM для JVM            |
| `JAVA_MIN_HEAP`     | `2048M`       | Начальный heap                  |
| `GIT_BRANCH`        | `main`        | Ветка синхронизации мира        |
| `PLAYIT_VERSION`    | `v1.0.8`      | Версия playit-agent             |

---

## Большие миры и Git LFS

GitHub ограничивает файлы **100 МБ**. Для тяжёлых миров:

```bash
git lfs install
git lfs track "world/**"
git add .gitattributes
git commit -m "Track world with Git LFS"
```

---

## Устранение неполадок

| Проблема | Решение |
|----------|---------|
| `UnsupportedClassVersionError` | Нужна Java 21: `java -version` |
| `unix_args.txt not found` | Удалите `libraries/` и перезапустите `./start.sh` |
| Create Aeronautics не грузится | Установите **Sable** + **Create** той же версии MC |
| `git push` отклонён | Проверьте `GITHUB_PAT` |
| OOM | Уменьшите `JAVA_MAX_HEAP` до `5500M` |
| Игроки не подключаются | Туннель playit → порт `25565` |
