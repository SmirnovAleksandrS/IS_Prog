"""
Data models for the glitch controller framework.
Minimal but extensible Pydantic v2 models.
"""

from pydantic import BaseModel
from enum import Enum
from typing import Optional, Literal, List, Dict, Any


class TriggerKind(str, Enum):
    """Types of trigger sources."""
    GPIO_LEVEL = "GPIO_LEVEL"       # implemented
    UART_EVENT = "UART_EVENT"       # stub


class AttackMode(str, Enum):
    """Types of glitch attacks."""
    CLOCK_GLITCH = "CLOCK_GLITCH"
    POWER_GLITCH = "POWER_GLITCH"   # stub


class ClockImpl(str, Enum):
    """Clock glitch implementation methods."""
    COMPRESS = "COMPRESS"           # implemented base
    EXTRA_EDGE = "EXTRA_EDGE"       # stub
    HF_MUX = "HF_MUX"               # stub
    PHASE_SWAP = "PHASE_SWAP"       # stub


class Outcome(str, Enum):
    """Trial outcome classifications (Russian labels)."""
    SUCCESS = "Успех"
    NO_EFFECT = "Нет эффекта"
    HANG = "Зависание"
    ERROR = "Ошибка стенда/протокола"


class TriggerSpec(BaseModel):
    """Specification for trigger configuration."""
    kind: TriggerKind
    edge: Literal["rising", "falling"] = "rising"
    timeout_ms: int = 200
    # UART_EVENT (stub) fields could be added later


class AttackSpec(BaseModel):
    """Specification for a single attack configuration."""
    mode: AttackMode = AttackMode.CLOCK_GLITCH
    clock_impl: ClockImpl = ClockImpl.COMPRESS
    tg_ns: int
    delay_ns: int
    # Concurrent power glitch (stub):
    power_enabled: bool = False
    power_type: Optional[Literal["UP", "DOWN"]] = None
    power_dv_mV: Optional[int] = None
    power_width_ns: Optional[int] = None
    power_delay_ns: Optional[int] = None


class Observation(BaseModel):
    """Raw observation data from the stand."""
    raw_status: Dict[str, Any]          # whatever stand returns
    trigger_seen: bool
    trigger_cleared: bool
    led_state: Optional[Literal["ON", "OFF", "BLINK"]] = None
    notes: Optional[str] = None


class Trial(BaseModel):
    """A single trial with attack parameters and results."""
    trial_id: int
    attack: AttackSpec
    trigger: TriggerSpec
    observation: Optional[Observation] = None
    outcome: Optional[Outcome] = None


class StrategyConfig(BaseModel):
    """Configuration for attack strategy."""
    name: Literal["grid", "random", "bayes", "bandit"] = "grid"
    params: Dict[str, Any] = {}


class CampaignConfig(BaseModel):
    """Configuration for a full attack campaign."""
    run_name: str
    max_trials: int
    trigger: TriggerSpec
    strategy: StrategyConfig
    reset_policy: Literal["soft", "hard", "none"] = "soft"
    safety_pause_ms: int = 10
