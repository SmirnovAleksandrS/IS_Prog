"""
ub (Управляющий блок) - Glitch Controller Framework

Core framework for orchestrating glitch attacks against AVR targets.
"""

from .orchestrator import Orchestrator
from .strategy import GridSearchStrategy, RandomSearchStrategy, create_strategy
from .protocol import MessageType, encode_frame, decode_stream
from .model import (
    AttackSpec, TriggerSpec, Trial, Observation, Outcome, 
    CampaignConfig, StrategyConfig, TriggerKind, AttackMode, ClockImpl
)

__all__ = [
    'Orchestrator',
    'GridSearchStrategy',
    'RandomSearchStrategy',
    'create_strategy',
    'MessageType',
    'encode_frame',
    'decode_stream',
    'AttackSpec',
    'TriggerSpec',
    'Trial',
    'Observation',
    'Outcome',
    'CampaignConfig',
    'StrategyConfig',
    'TriggerKind',
    'AttackMode',
    'ClockImpl',
]
