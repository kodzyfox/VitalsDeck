# 📋 Changelog / История изменений

All notable changes to **VitalsDeck** will be documented in this file.  
*Все значимые изменения в проекте VitalsDeck документируются в этом файле.*

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.0] — 2026-11-16

### 🛡️ Process Terminator & Safety / Безопасность процессов
- **PID Reuse Protection**: Проверка актуальности процесса перед отправкой сигналов `SIGTERM`/`SIGKILL`. Исключает ситуацию гонки, когда процесс завершился, а его PID перехватило другое приложение.
- **Kernel Verification (`proc_name`)**: Проверка живого имени процесса напрямую через системный вызов ядра macOS (`libproc`). Если процесс завершился или изменился, операция отменяется, а список процессов автоматически обновляется.
- **Protected System Processes**: Системные процессы с `PID <= 100` и защищенные демоны (`launchd`, `WindowServer`, `kernel_task` и др.) заблокированы от случайного принудительного завершения.

### ⚙️ Telemetry & System Monitoring / Мониторинг и метрики
- **Safe CPU Counter Delta**: Реализован расчет `cpuCounterDelta` с защитой от переполнения и сброса счетчиков процессорных тиков ядра.
- **Network Interface Crash Guard**: Добавлена проверка на `nil` для адресов интерфейсов `ifa_addr` в системном вызове `getifaddrs`, устраняющая возможный сбой на виртуальных или неинициализированных сетевых интерфейсах.
- **Accurate Temperature Reporting**: Если физический датчик температуры CPU временно недоступен, выводится честный статус `"N/A"` вместо грубой экстраполяции троттлинга.
- **Dual Temp Display**: В строке меню в режиме `.cpuAndGpuTemp` при отсутствии данных CPU, но наличии данных GPU, отображается `C:N/A G:XX°`.

### ☕ Caffeine Mode / Режим бодрствования
- **IOPMAssertion Lifecycle**: Корректная обработка и своевременный сброс идентификаторов `displayAssertionID` при сбое создания системной блокировки сна, предотвращающие утечку assertion в подсистеме управления питанием macOS.

### 🪟 Floating HUD / Плавающий оверлей
- **Reactive Layout Updates**: Добавлен метод `setLayout(_ layout:)`, мгновенно пересчитывающий границы панели при переключении между макетами и сохраняющий выбор в `UserDefaults`.

### 🧪 Testing / Автоматические тесты
- **Swift Testing Integration**: Добавлен тестовый таргет `VitalsDeckTests` на базе нового фреймворка Apple Swift Testing:
  - Тестирование преобразования интервалов `CaffeineDuration` в секунды и строковые метки.
  - Тестирование стабильности `SystemMonitor.cpuCounterDelta` при сбросе счетчиков.

### 🌐 Documentation & Web / Документация и сайт
- **Landing Page**: Интерактивная веб-страница проекта с встроенным видеоплеером (1080p демонстрация со звуком) и переключателем языков (EN / RU).
- **README Badges & Direct Links**: Обновлены прямые ссылки на загрузку `.dmg` и `.zip` релизов v1.2.0.

---

## [1.0.0] — 2026-09-26

### 🚀 Initial Release / Первый публичный релиз
- **Menu Bar Telemetry**: Вывод реальных температур Apple Silicon CPU & GPU и параметров в строку меню macOS.
- **Cyberpunk ASCII Meters**: Текстовые индикаторы нагрузки `[██████░░░░]` для CPU, GPU, RAM и сетевой активности.
- **5 Aesthetic Themes**: Темы Signal Amber, Matrix Green, Tokyo Neon, OLED Mono и Nord Frost.
- **Floating HUD**: Плавающее окно с примагничиванием к границам экрана и под камеру (Notch).
- **Caffeine Mode**: Блокировка засыпания Mac в один клик с таймерами (`20m`, `30m`, `1h`, `2h`, `3h`, `∞`).
- **Process Terminator**: Быстрое завершение ресурсоемких процессов.
- **Localization**: Поддержка английского и русского языков.
