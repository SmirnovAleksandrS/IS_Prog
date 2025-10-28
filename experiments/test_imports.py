"""
Simple test to verify framework imports work correctly.
"""

# Test core imports
from ub import (
    Orchestrator,
    GridSearchStrategy,
    RandomSearchStrategy,
    MessageType,
    encode_frame,
    decode_stream,
    AttackSpec,
    TriggerSpec,
    Trial,
    Outcome,
)

# Test experiments convenience imports
from experiments import (
    AttackSpec as ExpAttackSpec,
    TriggerSpec as ExpTriggerSpec,
    Outcome as ExpOutcome,
)

print("✅ Все импорты успешно загружены!")
print(f"   - Доступные исходы: {[o.value for o in Outcome]}")
print(f"   - Типы сообщений: {len(list(MessageType))} типов")
print(f"   - Классы стратегий: GridSearchStrategy, RandomSearchStrategy")
print("\n🎯 Фреймворк готов к использованию!")
