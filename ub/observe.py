"""
Outcome classification from raw stand observations.
Simple rule-based evaluator plus stubs for advanced methods.
"""

from .model import Observation, Outcome


class Evaluator:
    """Simple rule-based outcome classifier."""
    
    @staticmethod
    def classify(observation: Observation) -> Outcome:
        """
        Classify trial outcome based on observation.
        
        Rules (Russian outcome labels):
        - No trigger seen: ERROR
        - Trigger seen + (LED ON or trigger cleared): SUCCESS
        - Hang detected: HANG
        - Otherwise: NO_EFFECT
        
        Args:
            observation: Raw observation from stand
        
        Returns:
            Classified outcome
        """
        # Check for protocol/stand errors
        if not observation.trigger_seen:
            return Outcome.ERROR
        
        # Check for success indicators
        if observation.trigger_cleared or observation.led_state == "ON":
            return Outcome.SUCCESS
        
        # Check for hang
        raw = observation.raw_status
        if raw.get('hang', False):
            return Outcome.HANG
        
        # Default: no visible effect
        return Outcome.NO_EFFECT


class MLClassifier:
    """
    Machine learning-based outcome classifier (STUB).
    
    Could use probabilistic classification based on richer signal features
    (e.g., current spikes, timing anomalies, partial state changes).
    """
    
    def __init__(self):
        raise NotImplementedError("🚧 Функция пока не реализована (ML классификатор)")
    
    def classify(self, observation: Observation) -> Outcome:
        """Probabilistic outcome classification."""
        raise NotImplementedError()
    
    def train(self, observations: list, labels: list) -> None:
        """Train classifier on labeled data."""
        raise NotImplementedError()
