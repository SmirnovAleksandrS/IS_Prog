Below is a **concise, developer-facing spec** for a research-style Python framework that implements the **Controller (Управляющий блок)** for your glitch stand. It favors a **minimal, working base** with clear **extension points** (stubs/classes) you can later fill in. The **runtime interface (CLI, logs, plots)** is in **Russian**, but the spec and code identifiers are in English.

---

# Project overview (research style)

* Goal: orchestrate repeatable glitch experiments against an AVR “victim” via a UART-connected “stand”, log outcomes, visualize statistics, and iteratively propose next attacks.
* Base features implemented now:

  * UART link, simple protocol framing (`0x7E`, type, len, payload, CRC32)
  * **One trigger** type `GPIO_LEVEL` and **one injector** type `CLOCK_GLITCH` in a **simple COMPRESS mode** with `{tg_ns, delay_ns}`.
  * **Grid Search** and **Random Search** strategies.
  * JSONL logging + minimal SQLite/DuckDB export + quick heatmap visualization.
  * Simple outcome classification (`Успех`, `Нет эффекта`, `Зависание`) from basic stand status.
* Advanced features are **present as stubs** (clean class skeletons, config-selectable) but not implemented (fail fast if chosen):

  * `POWER_GLITCH`, combined attacks, multi-trigger, Bayesian optimization, White-box AVR cycle mapping, Bandits, multi-objective, etc.

The project is small, easy to extend. Crashes in non-critical areas are acceptable (research mode).

---

# Directory layout

```
glitch_controller/
├─ config.yaml                   # Run configuration (simple defaults, extensible)
├─ README.md                     # Short usage in RU
├─ experiments/                  # "arena" for quick scripts / notebooks
│  └─ __init__.py                # Re-exports main public API for convenience
└─ ub/                           # Core framework ("Управляющий блок")
   ├─ __init__.py
   ├─ cli.py                     # RU CLI: run/resume/report
   ├─ model.py                   # Data models (pydantic v2)
   ├─ serial_link.py             # pyserial wrapper
   ├─ protocol.py                # Framing, MessageType, CRC32, encode/decode
   ├─ orchestrator.py            # Simple FSM for trials & campaign
   ├─ strategy.py                # Grid/Random (impl), others (stubs)
   ├─ storage.py                 # JSONL event store + light SQL export
   ├─ observe.py                 # Simple outcome rules; advanced stubs
   └─ viz.py                     # Heatmap & timelines (RU labels)
```

> Keep it lean. Add new files only when absolutely necessary.

---

# `config.yaml` (put in repo root)

```yaml
# App language: all terminal UI messages are in Russian.
app:
  run_name: "avr_password_bypass_baseline"
  seed: 42
  artifacts_dir: "./runs/avr_password_bypass_baseline"

serial:
  port: "/dev/ttyUSB0"     # change on Windows to COM5, etc.
  baudrate: 115200
  timeout_s: 0.5

protocol:
  sof_hex: "0x7E"
  use_len1_byte: true       # as per spec: 1-byte LEN for now
  crc32_poly: "0xEDB88320"  # just for reference; Python will use binascii.crc32

campaign:
  max_trials: 2000
  reset_policy: "soft"      # soft | hard | none
  safety_pause_ms: 10       # pause between trials to avoid overheating
  trigger:
    kind: "GPIO_LEVEL"      # implemented base trigger
    edge: "rising"          # rising|falling
    timeout_ms: 200         # fail trial if no trigger
  attack:
    mode: "CLOCK_GLITCH"    # available now: CLOCK_GLITCH
    clock_impl: "COMPRESS"  # implemented; choices: COMPRESS | EXTRA_EDGE (stub) | HF_MUX (stub) | PHASE_SWAP (stub)
    concurrent_power: false # if true (stub) try to also fire power glitch
  strategy:
    name: "grid"            # "grid" (implemented) | "random" (implemented) | "bayes" (stub) | "bandit" (stub)
    params:
      tg_ns: [120, 100, 80, 64, 59, 50, 46, 40, 32, 28, 24, 20, 18, 16, 15]
      delay_ns: {start: 0, stop: 5000, step: 50}
      repeats_per_point: 3  # for stability; orchestrator will schedule repeats
storage:
  jsonl_path: "./runs/avr_password_bypass_baseline/events.jsonl"
  sqlite_path: "./runs/avr_password_bypass_baseline/results.sqlite"  # optional export
viz:
  live: false
  make_heatmap: true
  heatmap_metric: "success_rate" # success_rate | hang_rate | no_effect_rate
  output_dir: "./runs/avr_password_bypass_baseline/viz"
advanced:                       # placeholders for future extensions (safe to ignore now)
  power_glitch: {enabled: false, type: "DOWN", dV_mV: 250, width_ns: 60, delay_ns: 100}
  whitebox: {enabled: false, avr_listing_path: null}
  bayes: {enabled: false}
  bandit: {enabled: false}
```

* Defaults pick the **simplest working** path (GPIO trigger, CLOCK_GLITCH/COMPRESS, grid search).
* Switching to advanced names is **config-only** once you implement the stubs.

---

# File-by-file spec

## `ub/__init__.py`

* Re-export the primary public API for quick experimentation:

```python
from .orchestrator import Orchestrator
from .strategy import GridSearchStrategy, RandomSearchStrategy
from .protocol import MessageType, encode_frame, decode_stream
from .model import AttackSpec, TriggerSpec, Trial, Outcome, CampaignConfig
```

## `ub/model.py`

**Purpose:** strictly typed domain models; minimal but extensible.

Implement using **pydantic v2** (BaseModel). Keep comments short.

Key classes (fields kept minimal + docstrings):

```python
from pydantic import BaseModel
from enum import Enum
from typing import Optional, Literal, List, Dict, Any

class TriggerKind(str, Enum):
    GPIO_LEVEL = "GPIO_LEVEL"       # implemented
    UART_EVENT = "UART_EVENT"       # stub

class AttackMode(str, Enum):
    CLOCK_GLITCH = "CLOCK_GLITCH"
    POWER_GLITCH = "POWER_GLITCH"   # stub

class ClockImpl(str, Enum):
    COMPRESS = "COMPRESS"           # implemented base
    EXTRA_EDGE = "EXTRA_EDGE"       # stub
    HF_MUX = "HF_MUX"               # stub
    PHASE_SWAP = "PHASE_SWAP"       # stub

class Outcome(str, Enum):
    SUCCESS = "Успех"
    NO_EFFECT = "Нет эффекта"
    HANG = "Зависание"
    ERROR = "Ошибка стенда/протокола"

class TriggerSpec(BaseModel):
    kind: TriggerKind
    edge: Literal["rising", "falling"] = "rising"
    timeout_ms: int = 200
    # UART_EVENT (stub) fields could be added later

class AttackSpec(BaseModel):
    mode: AttackMode = AttackMode.CLOCK_GLITCH
    clock_impl: ClockImpl = ClockImpl.COMPRESS
    tg_ns: int
    delay_ns: int
    # Concurrent power glitch (stub):
    power_enabled: bool = False
    power_type: Optional[Literal["UP","DOWN"]] = None
    power_dv_mV: Optional[int] = None
    power_width_ns: Optional[int] = None
    power_delay_ns: Optional[int] = None

class Observation(BaseModel):
    raw_status: Dict[str, Any]          # whatever stand returns
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

**Purpose:** minimal `pyserial` wrapper. No over-engineering; let it fail loudly if device absent.

Implement:

* `SerialLink(port, baudrate, timeout_s)` context manager
* `.write(b: bytes) -> None`
* `.read(n: int) -> bytes` (blocking up to timeout)

CLI messages/logs in **Russian** (“Открыт порт…”, “Тайм-аут чтения…”).

## `ub/protocol.py`

**Purpose:** very small framing layer consistent with your spec.

Frame format (base):

```
[SOF=0x7E][TYPE:1][LEN:1][PAYLOAD:LEN][CRC32:4]
CRC32 over TYPE+LEN+PAYLOAD (little-endian 4 bytes)
```

* Use `binascii.crc32`.
* Add **Enums** for `MessageType`:

```python
from enum import IntEnum

class MessageType(IntEnum):
    SET_ATTACK   = 0x01
    ARM_TRIGGERS = 0x02
    FIRE         = 0x03
    READ_STATUS  = 0x04
    SOFT_RESET   = 0x05
    HARD_RESET   = 0x06

    ACK          = 0x10
    NACK         = 0x11
    PING         = 0x20
    PONG         = 0x21

    GET_CAPS     = 0x30
    TRACE_DUMP   = 0x31
```

Functions to implement:

* `encode_frame(msg_type: MessageType, payload: bytes) -> bytes`
* `decode_stream(buffer: bytearray) -> list[tuple[MessageType, bytes]]`

  * naive parser: scan for `0x7E`, check length, CRC; produce complete frames; leave residual in `buffer`.

Payload shaping (base, JSON-ish):

* For simplicity, encode most payloads as **little TLV** or JSON:

  * `SET_ATTACK`: JSON `{ "mode":"CLOCK_GLITCH", "clock_impl":"COMPRESS", "tg_ns":..., "delay_ns":... }`
  * `ARM_TRIGGERS`: JSON `{ "kind":"GPIO_LEVEL", "edge":"rising", "timeout_ms":200 }`
  * `FIRE`: empty payload
  * `READ_STATUS`: empty payload → stand replies with JSON status
* Advanced binary packing can be added later.

## `ub/strategy.py`

**Purpose:** minimal working strategies + placeholders.

Interfaces:

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

Implement:

* `GridSearchStrategy`:

  * Build explicit grid over `tg_ns` list and `delay_ns` range `{start, stop, step}`.
  * `repeats_per_point` handled by pushing same point multiple times.
* `RandomSearchStrategy`:

  * Uniform sampling over given ranges (infer from grid config for simplicity).

Stubs (config-selectable, raise `NotImplementedError`):

* `BayesOptStrategy`
* `BanditStrategy`
* `WindowHunterStrategy` (white-box)

## `ub/observe.py`

**Purpose:** turn raw stand status into an `Outcome`.

Implement `class Evaluator` with:

* `def classify(observation: Observation) -> Outcome`:

  * Simple rules in Russian:

    * if not `trigger_seen`: `Outcome.ERROR`
    * elif `trigger_seen` and (`led_state == "ON"` or `trigger_cleared`): `Outcome.SUCCESS`
    * elif timeout or stand reported “hang”: `Outcome.HANG`
    * else: `Outcome.NO_EFFECT`

Provide stubs:

* `MLClassifier` (stub) for future probabilistic classification.

## `ub/storage.py`

**Purpose:** research-style persistence (no fancy durability).

Implement:

* `EventStoreJSONL(path: str)`:

  * `.append(obj: dict) -> None` (write one JSON per line, RU timestamp fields)
  * `.flush()` (optional)
* `export_to_sqlite(jsonl_path, sqlite_path)` (optional convenience)
* Directory structure under `artifacts_dir`: save quick CSV exports for plotting.

## `ub/viz.py`

**Purpose:** quick plots with **Russian labels**.

Implement minimal:

* `save_heatmap(trials, outdir, metric="success_rate")`

  * Build a 2D grid (tg_ns × delay_ns), compute success rate, draw a heatmap (matplotlib), label axes in Russian, save PNG.
* `save_timeline(trials, outdir)`

  * Very simple strip plot by trial_id showing `FIRE` time and result class (optional; can be a TODO placeholder with a simple text legend now).

**Note:** Keep visualization light; more advanced dashboards can be added later.

## `ub/orchestrator.py`

**Purpose:** small FSM to run trials from a campaign config. Minimal, readable, fails fast.

Key points:

* Russian logging/messages.
* Steps per trial:

  1. (optional) reset victim according to `reset_policy` (send `SOFT_RESET` or `HARD_RESET`).
  2. `ARM_TRIGGERS`
  3. `SET_ATTACK`
  4. Wait “arming ok” ACK.
  5. Wait for trigger (poll `READ_STATUS` until `trigger_seen` or timeout).
  6. `FIRE`
  7. Poll `READ_STATUS` for a short observation window.
  8. Classify outcome; log JSONL event.
  9. safety pause.

Provide **Orchestrator** class:

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
        # parse into CampaignConfig etc.
        # init serial, event-store, strategy

    def _send_json(self, link: SerialLink, t: MessageType, payload_obj: dict):
        # encode json -> bytes -> frame -> write

    def _read_frames(self, link: SerialLink, timeout_s: float = 0.5):
        # naive buffer read + decode_stream

    def run(self):
        print("⏳ Запуск кампании…")
        # main loop until max_trials reached:
        #  - strategy.propose(...)
        #  - for each AttackSpec: perform a trial; append to JSONL
        #  - handle minimal errors (raise; do not conceal)
        print("✅ Кампания завершена.")
```

* Strategy selection based on config:

  * `"grid" → GridSearchStrategy`, `"random" → RandomSearchStrategy`, others raise `NotImplementedError`.
* Outcome classification via `Evaluator`.

## `ub/cli.py`

**Purpose:** thin RU CLI (argparse). Commands:

* `run --config config.yaml`
* `resume --config config.yaml` (simple: just call run; event store can be appended)
* `report --config config.yaml` (call viz/save_heatmap; basic CSV export)

**Strings in Russian**, e.g., “Ошибка протокола”, “Нет ответа от стенда”, etc.

---

# `experiments/__init__.py`

Expose frequently used top-level imports for notebooks/scripts:

```python
from ub.orchestrator import Orchestrator
from ub.strategy import GridSearchStrategy, RandomSearchStrategy
from ub.model import AttackSpec, TriggerSpec, Outcome, CampaignConfig
```

(Keep this file minimal; add more exports only as needed.)

---

# `README.md` (short RU)

* How to install (venv + `pip install pyserial pydantic matplotlib duckdb`).
* How to run: `python -m ub.cli run --config config.yaml`
* Where outputs go (`runs/<name>/...`).
* How to switch strategy/attack in `config.yaml`.
* Note that advanced options are stubs and will raise `NotImplementedError` (by design).

---

# Advanced (stubs list)

All stubs must be **wired in config** (selectable by name) but raise `NotImplementedError` until implemented:

* Strategies:

  * `BayesOptStrategy` (name `"bayes"`)
  * `BanditStrategy` (name `"bandit"`)
  * `WindowHunterStrategy` leveraging AVR white-box (“prefetch/LD/LPM windows”)
* Attacks:

  * `clock_impl`: `"EXTRA_EDGE" | "HF_MUX" | "PHASE_SWAP"`
  * `POWER_GLITCH` concurrent mode (fields already present in `AttackSpec`)
* Triggers:

  * `UART_EVENT` (e.g., react to last byte of password TX)
* Observe:

  * `MLClassifier` (probabilistic outcome from richer signals)
* Viz:

  * Live dashboard (Plotly Dash) and richer timelines

Each stub should have a **class/function skeleton**, be **importable**, and be **config-selectable**, but immediately raise with a **clear Russian message** (“Функция пока не реализована”).

---

# Minimal protocol notes for the stand (for reference)

* `SET_ATTACK`: JSON payload with `mode`, `clock_impl`, `tg_ns`, `delay_ns` (and power fields if enabled later). Stand replies `ACK`.
* `ARM_TRIGGERS`: JSON payload with `kind`, `edge`, `timeout_ms`. Stand replies `ACK` once armed.
* `FIRE`: empty payload. Stand initiates injection at next trigger match or immediately if already matched (implementation choice).
* `READ_STATUS`: empty payload. Stand replies with JSON status like:

  ```json
  {"trigger_seen": true, "trigger_cleared": true, "led_state": "ON", "hang": false, "notes": ""}
  ```
* `SOFT_RESET`/`HARD_RESET`: empty payload. `ACK` after action.

(If your current stand FW differs, adjust payloads in `protocol.py` only.)

---

# What to actually implement now (MVP checklist)

1. **Config loader** in `cli.py` (yaml → dict).
2. **Models** in `model.py`.
3. **SerialLink** in `serial_link.py` using `pyserial`.
4. **Protocol** in `protocol.py` (encode/decode, enums).
5. **Strategies**: `GridSearchStrategy`, `RandomSearchStrategy`.
6. **Observer/Evaluator** simple rule-based.
7. **Storage**: JSONL event log; small CSV export helper (optional).
8. **Viz**: single heatmap PNG with Russian labels.
9. **Orchestrator**: simple FSM loop, minimal error handling, Russian prints.

Everything else is a **stub** but present & selectable (so future code “just works” once implemented).

---

## Russian UI wording (samples)

* Start: `⏳ Запуск кампании «{run_name}» …`
* Serial open: `🔌 Открыт порт {port} @ {baudrate} бод`
* Trial: `▶️  Попытка #{trial_id}: Tg={tg_ns}нс, Delay={delay_ns}нс`
* Trigger wait: `⏱ Ожидание триггера (тайм-аут {timeout_ms}мс)…`
* Fire: `⚡ Инжекция глитча…`
* Outcome success: `✅ Успех`
* Outcome no effect: `➖ Нет эффекта`
* Outcome hang: `🛑 Зависание`
* End: `📦 Логи: {jsonl_path}; Графики: {viz_dir}`
* Not implemented: `🚧 Функция пока не реализована (см. advanced.* в config.yaml)`

---

That’s it. Hand this spec to Copilot (or implement directly) to get a working baseline. You’ll be able to **switch to advanced tactics just via `config.yaml`** once those stubs are filled in, without reshaping the project.
