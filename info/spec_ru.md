Ниже — краткая, ориентированная на разработчика спецификация для исследовательского Python-фреймворка, реализующего «Управляющий блок» (Controller) для стенда глитчей. Ставится задача минимальной рабочей базы с понятными точками расширения (заглушки/классы). Интерфейс запуска (CLI, логи, графики) — на русском, идентификаторы и спецификация — на английском.

---

# Обзор проекта (research style)

- Цель: оркестрация воспроизводимых глитч-экспериментов против AVR «victim» через UART-подключённый стенд, логирование результатов, визуализация статистики и итеративное предложение следующих атак.
- Реализованные базовые возможности:

  - UART-связь, простая утильная кадровая обёртка (`0x7E`, type, len, payload, CRC32)
  - Одна реализация триггера — `GPIO_LEVEL` и один тип инжектора — `CLOCK_GLITCH` в простом режиме `COMPRESS` с параметрами `{tg_ns, delay_ns}`.
  - Стратегии поиска: Grid Search и Random Search.
  - Логирование в JSONL + минимальный экспорт в SQLite/DuckDB + быстрые тепловые карты для визуализации.
  - Простая классификация исхода (`Успех`, `Нет эффекта`, `Зависание`) по базовому статусу стенда.

- Продвинутые возможности присутствуют как заглушки (чистые скелеты классов, конфигурируемые) и при выборе приводят к явному `NotImplementedError`:

  - `POWER_GLITCH`, комбинированные атаки, мульти-триггер, Bayesian optimization, white-box AVR cycle mapping, Bandits, multi-objective и т.п.

Проект небольшой и легко расширяемый. В рамках research-моды допустимы аварийные падения в не-критичных местах.

---

# Структура директории

```
glitch_controller/
├─ config.yaml                   # Конфиг запуска (простые значения по умолчанию, расширяемо)
├─ README.md                     # Краткая инструкция (RU)
├─ experiments/                  # Быстрые скрипты / ноутбуки
│  └─ __init__.py                # Удобные ре-экспорты публичного API
└─ ub/                           # Ядро фреймворка ("Управляющий блок")
   ├─ __init__.py
   ├─ cli.py                     # RU CLI: run/resume/report
   ├─ model.py                   # Модели данных (pydantic v2)
   ├─ serial_link.py             # Обёртка pyserial
   ├─ protocol.py                # Фрейминг, MessageType, CRC32, encode/decode
   ├─ orchestrator.py            # Простой конечный автомат для trial'ов и кампании
   ├─ strategy.py                # Grid/Random (реализованы), остальные — заглушки
   ├─ storage.py                 # JSONL event store + лёгкий SQL экспорт
   ├─ observe.py                 # Правила наблюдений → Outcome; advanced — заглушки
   └─ viz.py                     # Тепловые карты и таймлайны (RU подписи)
```

> Держать проект лёгким. Добавлять файлы только при крайней необходимости.

---

# `config.yaml` (в корне)

Пример содержимого конфигурации (по-умолчанию выбирается максимально простой рабочий путь):

```yaml
# Язык приложения: все сообщения терминала — на русском.
app:
  run_name: "avr_password_bypass_baseline"
  seed: 42
  artifacts_dir: "./runs/avr_password_bypass_baseline"

serial:
  port: "/dev/ttyUSB0"     # на Windows поменять на COM5 и т.п.
  baudrate: 115200
  timeout_s: 0.5

protocol:
  sof_hex: "0x7E"
  use_len1_byte: true       # пока 1-байтный LEN
  crc32_poly: "0xEDB88320"

campaign:
  max_trials: 2000
  reset_policy: "soft"      # soft | hard | none
  safety_pause_ms: 10
  trigger:
    kind: "GPIO_LEVEL"
    edge: "rising"
    timeout_ms: 200
  attack:
    mode: "CLOCK_GLITCH"
    clock_impl: "COMPRESS"
    concurrent_power: false
  strategy:
    name: "grid"
    params:
      tg_ns: [120, 100, 80, 64, 59, 50, 46, 40, 32, 28, 24, 20, 18, 16, 15]
      delay_ns: {start: 0, stop: 5000, step: 50}
      repeats_per_point: 3
storage:
  jsonl_path: "./runs/avr_password_bypass_baseline/events.jsonl"
  sqlite_path: "./runs/avr_password_bypass_baseline/results.sqlite"
viz:
  live: false
  make_heatmap: true
  heatmap_metric: "success_rate"
  output_dir: "./runs/avr_password_bypass_baseline/viz"
advanced:
  power_glitch: {enabled: false, type: "DOWN", dV_mV: 250, width_ns: 60, delay_ns: 100}
  whitebox: {enabled: false, avr_listing_path: null}
  bayes: {enabled: false}
  bandit: {enabled: false}
```

---

# Файл за файлом — что реализовать

Ниже перечислены ключевые файлы и задачи для минимальной рабочей реализации.

## `ub/__init__.py`

Ре-экспорт основных API для быстрой работы в интерактивных сценариях:

```python
from .orchestrator import Orchestrator
from .strategy import GridSearchStrategy, RandomSearchStrategy
from .protocol import MessageType, encode_frame, decode_stream
from .model import AttackSpec, TriggerSpec, Trial, Outcome, CampaignConfig
```

## `ub/model.py`

Назначение: строго типизированные доменные модели; минимально, но расширяемо.

Использовать `pydantic v2` (BaseModel). Краткие docstring'и.

Ключевые классы:

```python
from pydantic import BaseModel
from enum import Enum
from typing import Optional, Literal, List, Dict, Any

class TriggerKind(str, Enum):
    GPIO_LEVEL = "GPIO_LEVEL"
    UART_EVENT = "UART_EVENT"  # заглушка

class AttackMode(str, Enum):
    CLOCK_GLITCH = "CLOCK_GLITCH"
    POWER_GLITCH = "POWER_GLITCH"  # заглушка

class ClockImpl(str, Enum):
    COMPRESS = "COMPRESS"
    EXTRA_EDGE = "EXTRA_EDGE"
    HF_MUX = "HF_MUX"
    PHASE_SWAP = "PHASE_SWAP"

class Outcome(str, Enum):
    SUCCESS = "Успех"
    NO_EFFECT = "Нет эффекта"
    HANG = "Зависание"
    ERROR = "Ошибка стенда/протокола"

class TriggerSpec(BaseModel):
    kind: TriggerKind
    edge: Literal["rising", "falling"] = "rising"
    timeout_ms: int = 200

class AttackSpec(BaseModel):
    mode: AttackMode = AttackMode.CLOCK_GLITCH
    clock_impl: ClockImpl = ClockImpl.COMPRESS
    tg_ns: int
    delay_ns: int
    power_enabled: bool = False
    power_type: Optional[Literal["UP","DOWN"]] = None
    power_dv_mV: Optional[int] = None
    power_width_ns: Optional[int] = None
    power_delay_ns: Optional[int] = None

class Observation(BaseModel):
    raw_status: Dict[str, Any]
    trigger_seen: bool
    trigger_cleared: bool
    led_state: Optional[Literal["ON","OFF"]] = None
    notes: Optional[str] = None

class Trial(BaseModel):
    trial_id: int
    attack: AttackSpec
    trigger: TriggerSpec
    observation: Optional[Observation] = None
    outcome: Optional[Outcome] = None

class StrategyConfig(BaseModel):
    name: Literal["grid","random","bayes","bandit"] = "grid"
    params: Dict[str, Any] = {}

class CampaignConfig(BaseModel):
    run_name: str
    max_trials: int
    trigger: TriggerSpec
    strategy: StrategyConfig
    reset_policy: Literal["soft","hard","none"] = "soft"
    safety_pause_ms: int = 10
```

## `ub/serial_link.py`

Назначение: минимальная обёртка над `pyserial`. Пусть падает явно, если устройства нет.

Реализовать:

- `SerialLink(port, baudrate, timeout_s)` — контекстный менеджер
- `.write(b: bytes) -> None`
- `.read(n: int) -> bytes` (блокирует до `timeout`)

Лог-сообщения в RU: например, “Открыт порт…”, “Тайм-аут чтения…”.

## `ub/protocol.py`

Назначение: лёгкий фрейминг по спецификации.

Формат кадра:

```
[SOF=0x7E][TYPE:1][LEN:1][PAYLOAD:LEN][CRC32:4]
```

- CRC32 по полю TYPE+LEN+PAYLOAD (использовать `binascii.crc32`).
- Enum `MessageType` (IntEnum) с указанными значениями.

Функции:

- `encode_frame(msg_type: MessageType, payload: bytes) -> bytes`
- `decode_stream(buffer: bytearray) -> list[tuple[MessageType, bytes]]`

Парсер может быть наивным: сканировать `0x7E`, проверять длину и CRC, возвращать полные кадры, оставлять остаток в буфере.

Payload'ы — JSON-ориентированные для простоты:

- `SET_ATTACK`: JSON с полями `mode`, `clock_impl`, `tg_ns`, `delay_ns` и т.д.
- `ARM_TRIGGERS`: JSON `{ "kind":"GPIO_LEVEL", "edge":"rising", "timeout_ms":200 }`
- `FIRE`, `READ_STATUS` — пустые полезные данные; в ответ стенд шлёт JSON-статус.

## `ub/strategy.py`

Назначение: рабочие стратегии + заглушки.

Интерфейс:

```python
from abc import ABC, abstractmethod
from typing import List
from .model import AttackSpec, TriggerSpec, Trial, StrategyConfig

class Strategy(ABC):
    def __init__(self, cfg: StrategyConfig, trigger: TriggerSpec):
        self.cfg = cfg
        self.trigger = trigger

    @abstractmethod
    def propose(self, history: List[Trial], n: int) -> List[AttackSpec]:
        ...

    def observe(self, trials: List[Trial]) -> None:
        pass
```

Реализовать:

- `GridSearchStrategy`:
  - Построить явную сетку по списку `tg_ns` и диапазону `delay_ns` `{start, stop, step}`.
  - `repeats_per_point` — повторять точки нужное число раз.
- `RandomSearchStrategy`:
  - Равномерная выборка по тем же диапазонам (для простоты можно выводить из grid-конфига).

Заглушки (должны быть конфигурируемыми и бросать `NotImplementedError`):

- `BayesOptStrategy`
- `BanditStrategy`
- `WindowHunterStrategy`

## `ub/observe.py`

Назначение: преобразование raw-статуса стенда в `Outcome`.

Реализовать `class Evaluator` с методом:

- `def classify(observation: Observation) -> Outcome`:

  Простые правила (на русском):

  - если `not trigger_seen`: `Outcome.ERROR`
  - elif `trigger_seen` и (`led_state == "ON"` или `trigger_cleared`): `Outcome.SUCCESS`
  - elif таймаут или стенд сообщил "hang": `Outcome.HANG`
  - иначе: `Outcome.NO_EFFECT`

Поставить заглушку `MLClassifier` для будущего.

## `ub/storage.py`

Назначение: исследовательское хранение (не обязателен сложный уровень отказоустойчивости).

Реализовать:

- `EventStoreJSONL(path: str)`:
  - `.append(obj: dict) -> None` — записывает JSON в одну строку (проставить RU-временные метки)
  - `.flush()` (опционально)
- `export_to_sqlite(jsonl_path, sqlite_path)` — удобная утилита (опционально)

Сохранить экспорты/артефакты в `artifacts_dir`.

## `ub/viz.py`

Назначение: простые графики с подписями на русском.

Реализовать минимальный набор:

- `save_heatmap(trials, outdir, metric="success_rate")`:
  - Построить 2D-сетку (tg_ns × delay_ns), вычислить success rate, сохранить PNG (matplotlib).
  - Оси и подписи — на русском.
- `save_timeline(trials, outdir)`:
  - Простой strip-plot или placeholder с легендой (текстовая плейсхолдер-должна быть допустимой реализацией).

## `ub/orchestrator.py`

Назначение: небольшой FSM для исполнения trial'ов по конфигу кампании. Минималистично, читаемо, падать явно при ошибках.

Ключевые шаги для каждого trial'а:

1. (опционально) сброс "victim" согласно `reset_policy` (отправить `SOFT_RESET` или `HARD_RESET`).
2. `ARM_TRIGGERS`
3. `SET_ATTACK`
4. Дождаться ACK на этапе арминга.
5. Ожидать триггер (poll `READ_STATUS` до `trigger_seen` или таймаута).
6. `FIRE`
7. Опрос `READ_STATUS` в коротком окне наблюдения.
8. Классификация исхода; запись в JSONL.
9. `safety_pause`

Предоставить класс `Orchestrator` со следующими методами/полями (примерное API):

```python
import time, json, logging
from .model import CampaignConfig, Trial, Observation, Outcome, AttackSpec
from .protocol import MessageType, encode_frame, decode_stream
from .serial_link import SerialLink
from .strategy import GridSearchStrategy, RandomSearchStrategy, Strategy
from .observe import Evaluator
from .storage import EventStoreJSONL

class Orchestrator:
    def __init__(self, cfg: dict):
        self.cfg = cfg
        # распарсить в CampaignConfig и т.д.

    def _send_json(self, link: SerialLink, t: MessageType, payload_obj: dict):
        # json -> bytes -> frame -> write

    def _read_frames(self, link: SerialLink, timeout_s: float = 0.5):
        # наивное чтение буфера + decode_stream

    def run(self):
        print("⏳ Запуск кампании…")
        # основной цикл до max_trials:
        #  - strategy.propose(...)
        #  - для каждого AttackSpec: выполнить trial; append в JSONL
        #  - простая обработка ошибок (raise)
        print("✅ Кампания завершена.")
```

Особенности:

- выбор стратегии по config: `grid` → `GridSearchStrategy`, `random` → `RandomSearchStrategy`, остальные бросают `NotImplementedError`.
- классификация исхода — через `Evaluator`.

## `ub/cli.py`

Назначение: тонкий RU CLI (argparse). Команды:

- `run --config config.yaml`
- `resume --config config.yaml` (простая реализация: вызвать run; event store будет дописан)
- `report --config config.yaml` (вызвать `viz.save_heatmap`; базовый CSV экспорт)

Все строки интерфейса — на русском: примеры — “Ошибка протокола”, “Нет ответа от стенда”.

---

# `experiments/__init__.py`

Экспорт часто используемых сущностей для ноутбуков/скриптов:

```python
from ub.orchestrator import Orchestrator
from ub.strategy import GridSearchStrategy, RandomSearchStrategy
from ub.model import AttackSpec, TriggerSpec, Outcome, CampaignConfig
```

---

# `README.md` (короткая инструкция на русском)

- Установка (venv + `pip install pyserial pydantic matplotlib duckdb`).
- Запуск: `python -m ub.cli run --config config.yaml`.
- Куда падают артефакты: `runs/<name>/...`.
- Как переключить стратегию/атаку — править `config.yaml`.
- Замечание: продвинутые опции — заглушки и при выборе вызовут `NotImplementedError` (по дизайну).

---

# Заглушки (stubs)

Все заглушки должны быть доступны для выбора из конфига, но при попытке использования бросать `NotImplementedError` с понятным сообщением на русском: `"🚧 Функция пока не реализована (см. advanced.* в config.yaml)"`.

Список заглушек:

- Стратегии: `BayesOptStrategy` (`name: "bayes"`), `BanditStrategy` (`"bandit"`), `WindowHunterStrategy`.
- Атаки: `clock_impl`: `EXTRA_EDGE | HF_MUX | PHASE_SWAP`.
- Триггеры: `UART_EVENT`.
- Observe: `MLClassifier`.
- Viz: live dashboard (Plotly Dash) — placeholder.

---

# Мин. набор для реализации (MVP checklist)

1. Загрузчик конфига в `cli.py` (yaml -> dict).
2. Модели в `model.py`.
3. `SerialLink` в `serial_link.py` (pyserial).
4. `protocol.py` (encode/decode, enums).
5. Стратегии: `GridSearchStrategy`, `RandomSearchStrategy`.
6. `observe.Evaluator` с простыми правилами.
7. `storage.EventStoreJSONL` и простой CSV экспортер (опционально).
8. `viz.save_heatmap` — одна PNG с подписями на русском.
9. `Orchestrator` — простой FSM loop, базовая обработка ошибок, русские print'ы.

Остальное — заглушки, но должно быть импортируемым и вызывать понятную ошибку.

---

# Образцы RU-строк интерфейса (подсказки для реализации)

- Старт: `⏳ Запуск кампании «{run_name}» …`
- Открыт порт: `🔌 Открыт порт {port} @ {baudrate} бод`
- Попытка: `▶️  Попытка #{trial_id}: Tg={tg_ns}нс, Delay={delay_ns}нс`
- Ожидание триггера: `⏱ Ожидание триггера (тайм-аут {timeout_ms}мс)…`
- Инжекция: `⚡ Инжекция глитча…`
- Успех: `✅ Успех`
- Нет эффекта: `➖ Нет эффекта`
- Зависание: `🛑 Зависание`
- Конец: `📦 Логи: {jsonl_path}; Графики: {viz_dir}`
- Не реализовано: `🚧 Функция пока не реализована (см. advanced.* в config.yaml)`

---

Это всё. Реализация по спецификации даёт компактную, расширяемую базу: можно добавлять продвинутые стратегии/метрики/визуализации только заполнением заглушек и не меняя API.
