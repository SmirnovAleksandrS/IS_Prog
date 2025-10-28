"""
Attack strategies: Grid Search, Random Search, and stubs for advanced methods.
"""

from abc import ABC, abstractmethod
from typing import List
import random
from .model import AttackSpec, TriggerSpec, Trial, StrategyConfig, AttackMode, ClockImpl


class Strategy(ABC):
    """Base class for attack strategies."""
    
    def __init__(self, cfg: StrategyConfig, trigger: TriggerSpec):
        self.cfg = cfg
        self.trigger = trigger
    
    @abstractmethod
    def propose(self, history: List[Trial], n: int) -> List[AttackSpec]:
        """
        Propose next n attack configurations.
        
        Args:
            history: List of completed trials
            n: Number of attacks to propose
        
        Returns:
            List of AttackSpec configurations
        """
        pass
    
    def observe(self, trials: List[Trial]) -> None:
        """
        Update strategy based on observed trials (optional).
        
        Args:
            trials: List of new trials to learn from
        """
        pass


class GridSearchStrategy(Strategy):
    """Exhaustive grid search over parameter space."""
    
    def __init__(self, cfg: StrategyConfig, trigger: TriggerSpec):
        super().__init__(cfg, trigger)
        self._grid = self._build_grid()
        self._current_idx = 0
    
    def _build_grid(self) -> List[AttackSpec]:
        """Build complete grid of attack configurations."""
        params = self.cfg.params
        tg_ns_values = params.get('tg_ns', [100])
        delay_ns_config = params.get('delay_ns', {'start': 0, 'stop': 1000, 'step': 100})
        repeats = params.get('repeats_per_point', 1)
        
        # Build delay_ns range
        delay_ns_values = list(range(
            delay_ns_config['start'],
            delay_ns_config['stop'],
            delay_ns_config['step']
        ))
        
        # Build grid
        grid = []
        for tg_ns in tg_ns_values:
            for delay_ns in delay_ns_values:
                for _ in range(repeats):
                    grid.append(AttackSpec(
                        mode=AttackMode.CLOCK_GLITCH,
                        clock_impl=ClockImpl.COMPRESS,
                        tg_ns=tg_ns,
                        delay_ns=delay_ns
                    ))
        
        return grid
    
    def propose(self, history: List[Trial], n: int) -> List[AttackSpec]:
        """Propose next n points from grid."""
        proposals = []
        for _ in range(n):
            if self._current_idx < len(self._grid):
                proposals.append(self._grid[self._current_idx])
                self._current_idx += 1
            else:
                break  # Grid exhausted
        return proposals


class RandomSearchStrategy(Strategy):
    """Random sampling over parameter space."""
    
    def __init__(self, cfg: StrategyConfig, trigger: TriggerSpec):
        super().__init__(cfg, trigger)
        params = self.cfg.params
        self.tg_ns_values = params.get('tg_ns', [100])
        delay_ns_config = params.get('delay_ns', {'start': 0, 'stop': 1000, 'step': 100})
        self.delay_ns_min = delay_ns_config['start']
        self.delay_ns_max = delay_ns_config['stop']
        
        # Set random seed if provided
        seed = params.get('seed', None)
        if seed is not None:
            random.seed(seed)
    
    def propose(self, history: List[Trial], n: int) -> List[AttackSpec]:
        """Propose n random attack configurations."""
        proposals = []
        for _ in range(n):
            tg_ns = random.choice(self.tg_ns_values)
            delay_ns = random.randint(self.delay_ns_min, self.delay_ns_max)
            proposals.append(AttackSpec(
                mode=AttackMode.CLOCK_GLITCH,
                clock_impl=ClockImpl.COMPRESS,
                tg_ns=tg_ns,
                delay_ns=delay_ns
            ))
        return proposals


class BayesOptStrategy(Strategy):
    """Bayesian optimization strategy (STUB)."""
    
    def __init__(self, cfg: StrategyConfig, trigger: TriggerSpec):
        super().__init__(cfg, trigger)
        raise NotImplementedError("🚧 Функция пока не реализована (см. advanced.bayes в config.yaml)")
    
    def propose(self, history: List[Trial], n: int) -> List[AttackSpec]:
        raise NotImplementedError()


class BanditStrategy(Strategy):
    """Multi-armed bandit strategy (STUB)."""
    
    def __init__(self, cfg: StrategyConfig, trigger: TriggerSpec):
        super().__init__(cfg, trigger)
        raise NotImplementedError("🚧 Функция пока не реализована (см. advanced.bandit в config.yaml)")
    
    def propose(self, history: List[Trial], n: int) -> List[AttackSpec]:
        raise NotImplementedError()


class WindowHunterStrategy(Strategy):
    """White-box window hunting strategy (STUB)."""
    
    def __init__(self, cfg: StrategyConfig, trigger: TriggerSpec):
        super().__init__(cfg, trigger)
        raise NotImplementedError("🚧 Функция пока не реализована (см. advanced.whitebox в config.yaml)")
    
    def propose(self, history: List[Trial], n: int) -> List[AttackSpec]:
        raise NotImplementedError()


def create_strategy(cfg: StrategyConfig, trigger: TriggerSpec) -> Strategy:
    """
    Factory function to create strategy from config.
    
    Args:
        cfg: Strategy configuration
        trigger: Trigger specification
    
    Returns:
        Strategy instance
    
    Raises:
        ValueError: If strategy name is unknown
    """
    strategies = {
        'grid': GridSearchStrategy,
        'random': RandomSearchStrategy,
        'bayes': BayesOptStrategy,
        'bandit': BanditStrategy,
        'window_hunter': WindowHunterStrategy,
    }
    
    strategy_class = strategies.get(cfg.name)
    if strategy_class is None:
        raise ValueError(f"Неизвестная стратегия: {cfg.name}")
    
    return strategy_class(cfg, trigger)
