"""
Example: Manual trial execution without full campaign.
Demonstrates how to use the framework components independently.
"""

import sys
sys.path.insert(0, 'C:\\projects\\IS_Prog')

from ub.model import AttackSpec, TriggerSpec, AttackMode, ClockImpl, TriggerKind
from ub.strategy import GridSearchStrategy, StrategyConfig

# Example 1: Create attack specifications manually
print("=" * 60)
print("ПРИМЕР 1: Создание спецификации атаки")
print("=" * 60)

attack = AttackSpec(
    mode=AttackMode.CLOCK_GLITCH,
    clock_impl=ClockImpl.COMPRESS,
    tg_ns=100,
    delay_ns=500
)

print(f"✅ Атака: {attack.mode.value}, Tg={attack.tg_ns}нс, Delay={attack.delay_ns}нс")

# Example 2: Create trigger specification
print("\n" + "=" * 60)
print("ПРИМЕР 2: Настройка триггера")
print("=" * 60)

trigger = TriggerSpec(
    kind=TriggerKind.GPIO_LEVEL,
    edge="rising",
    timeout_ms=200
)

print(f"✅ Триггер: {trigger.kind.value}, фронт={trigger.edge}, тайм-аут={trigger.timeout_ms}мс")

# Example 3: Use strategy to generate attack points
print("\n" + "=" * 60)
print("ПРИМЕР 3: Генерация точек атаки (Grid Search)")
print("=" * 60)

strategy_cfg = StrategyConfig(
    name="grid",
    params={
        'tg_ns': [100, 80, 64],
        'delay_ns': {'start': 0, 'stop': 500, 'step': 100},
        'repeats_per_point': 1
    }
)

strategy = GridSearchStrategy(strategy_cfg, trigger)
attacks = strategy.propose([], n=5)  # Get first 5 points

print(f"✅ Сгенерировано {len(attacks)} точек атаки:")
for i, attack in enumerate(attacks, 1):
    print(f"   {i}. Tg={attack.tg_ns}нс, Delay={attack.delay_ns}нс")

print("\n" + "=" * 60)
print("🎯 Для запуска полной кампании используйте:")
print("   python -m ub.cli run --config config.yaml")
print("=" * 60)
