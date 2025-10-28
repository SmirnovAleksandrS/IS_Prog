"""
Orchestrator: FSM to run trials from campaign config.
Minimal, readable, fails fast - research mode.
"""

import time
import random
from pathlib import Path
from typing import List, Optional
from .model import (
    CampaignConfig, Trial, AttackSpec, TriggerSpec, 
    Observation, Outcome, StrategyConfig
)
from .protocol import MessageType, encode_frame, decode_stream, encode_json_payload, decode_json_payload
from .serial_link import SerialLink
from .strategy import create_strategy, Strategy
from .observe import Evaluator
from .storage import EventStoreJSONL


class Orchestrator:
    """Main orchestrator for running glitch campaigns."""
    
    def __init__(self, config: dict):
        """
        Initialize orchestrator from config dictionary.
        
        Args:
            config: Full configuration dictionary loaded from YAML
        """
        self.config = config
        
        # Parse campaign config
        campaign_cfg = config['campaign']
        self.campaign = CampaignConfig(
            run_name=config['app']['run_name'],
            max_trials=campaign_cfg['max_trials'],
            trigger=TriggerSpec(**campaign_cfg['trigger']),
            strategy=StrategyConfig(**campaign_cfg['strategy']),
            reset_policy=campaign_cfg['reset_policy'],
            safety_pause_ms=campaign_cfg['safety_pause_ms']
        )
        
        # Serial config
        self.serial_config = config['serial']
        
        # Storage config
        self.storage_config = config['storage']
        
        # Create strategy
        self.strategy: Strategy = create_strategy(
            self.campaign.strategy,
            self.campaign.trigger
        )
        
        # Evaluator
        self.evaluator = Evaluator()
        
        # Trial history
        self.trials: List[Trial] = []
        
        # Set random seed
        seed = config['app'].get('seed')
        if seed is not None:
            random.seed(seed)
    
    def run(self) -> None:
        """Run the complete campaign."""
        print(f"⏳ Запуск кампании «{self.campaign.run_name}» ...")
        print(f"📊 Макс. испытаний: {self.campaign.max_trials}")
        print(f"🎯 Стратегия: {self.campaign.strategy.name}")
        
        # Create artifacts directory
        artifacts_dir = Path(self.config['app']['artifacts_dir'])
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        
        # Open serial link
        with SerialLink(
            self.serial_config['port'],
            self.serial_config['baudrate'],
            self.serial_config['timeout_s']
        ) as link:
            # Open event store
            with EventStoreJSONL(self.storage_config['jsonl_path']) as store:
                # Main campaign loop
                trial_count = 0
                
                while trial_count < self.campaign.max_trials:
                    # Ask strategy for next attack(s)
                    attacks = self.strategy.propose(self.trials, n=1)
                    
                    if not attacks:
                        print("✅ Стратегия исчерпана (нет больше точек)")
                        break
                    
                    for attack in attacks:
                        if trial_count >= self.campaign.max_trials:
                            break
                        
                        trial_count += 1
                        
                        # Run trial
                        trial = self._run_trial(
                            link, 
                            trial_count, 
                            attack, 
                            self.campaign.trigger
                        )
                        
                        # Store trial
                        self.trials.append(trial)
                        
                        # Log to JSONL
                        self._log_trial(store, trial)
                        
                        # Print outcome
                        self._print_trial_result(trial)
                        
                        # Safety pause
                        if self.campaign.safety_pause_ms > 0:
                            time.sleep(self.campaign.safety_pause_ms / 1000.0)
        
        print(f"✅ Кампания завершена. Всего испытаний: {len(self.trials)}")
        print(f"📦 Логи: {self.storage_config['jsonl_path']}")
    
    def _run_trial(
        self, 
        link: SerialLink, 
        trial_id: int, 
        attack: AttackSpec,
        trigger: TriggerSpec
    ) -> Trial:
        """
        Execute a single trial.
        
        Args:
            link: Serial link to stand
            trial_id: Trial number
            attack: Attack configuration
            trigger: Trigger configuration
        
        Returns:
            Completed Trial object
        """
        # Create trial
        trial = Trial(
            trial_id=trial_id,
            attack=attack,
            trigger=trigger
        )
        
        try:
            # Step 1: Optional reset
            self._reset_victim(link)
            
            # Step 2: Configure attack
            self._send_command(link, MessageType.SET_ATTACK, {
                'mode': attack.mode.value,
                'clock_impl': attack.clock_impl.value,
                'tg_ns': attack.tg_ns,
                'delay_ns': attack.delay_ns
            })
            
            # Step 3: Arm triggers
            self._send_command(link, MessageType.ARM_TRIGGERS, {
                'kind': trigger.kind.value,
                'edge': trigger.edge,
                'timeout_ms': trigger.timeout_ms
            })
            
            # Step 4: Wait for trigger (poll status)
            trigger_seen = self._wait_for_trigger(link, trigger.timeout_ms)
            
            # Step 5: Fire glitch
            self._send_command(link, MessageType.FIRE, {})
            
            # Step 6: Read observation
            time.sleep(0.05)  # Short observation window
            status = self._read_status(link)
            
            # Build observation
            observation = Observation(
                raw_status=status,
                trigger_seen=status.get('trigger_seen', False),
                trigger_cleared=status.get('trigger_cleared', False),
                led_state=status.get('led_state')
            )
            
            # Classify outcome
            outcome = self.evaluator.classify(observation)
            
            trial.observation = observation
            trial.outcome = outcome
            
        except Exception as e:
            # Log error but continue
            print(f"⚠️  Ошибка в испытании #{trial_id}: {e}")
            trial.outcome = Outcome.ERROR
            trial.observation = Observation(
                raw_status={'error': str(e)},
                trigger_seen=False,
                trigger_cleared=False,
                notes=str(e)
            )
        
        return trial
    
    def _reset_victim(self, link: SerialLink) -> None:
        """Reset victim according to policy."""
        if self.campaign.reset_policy == "soft":
            self._send_command(link, MessageType.SOFT_RESET, {})
        elif self.campaign.reset_policy == "hard":
            self._send_command(link, MessageType.HARD_RESET, {})
        # else: none - skip reset
    
    def _send_command(self, link: SerialLink, msg_type: MessageType, payload_dict: dict) -> None:
        """Send a command and wait for ACK."""
        payload = encode_json_payload(payload_dict) if payload_dict else b''
        frame = encode_frame(msg_type, payload)
        link.write(frame)
        
        # Wait for ACK (simple, with timeout)
        start = time.time()
        buffer = bytearray()
        
        while time.time() - start < 1.0:
            data = link.read_available()
            if data:
                buffer.extend(data)
                frames = decode_stream(buffer)
                for frame_type, frame_payload in frames:
                    if frame_type == MessageType.ACK:
                        return
                    elif frame_type == MessageType.NACK:
                        raise RuntimeError("Получен NACK от стенда")
            time.sleep(0.01)
        
        # Timeout - proceed anyway (research mode, fail soft)
    
    def _wait_for_trigger(self, link: SerialLink, timeout_ms: int) -> bool:
        """Wait for trigger to be seen."""
        start = time.time()
        timeout_s = timeout_ms / 1000.0
        
        while time.time() - start < timeout_s:
            status = self._read_status(link)
            if status.get('trigger_seen'):
                return True
            time.sleep(0.02)
        
        return False
    
    def _read_status(self, link: SerialLink) -> dict:
        """Read status from stand."""
        frame = encode_frame(MessageType.READ_STATUS, b'')
        link.write(frame)
        
        # Wait for response
        start = time.time()
        buffer = bytearray()
        
        while time.time() - start < 0.5:
            data = link.read_available()
            if data:
                buffer.extend(data)
                frames = decode_stream(buffer)
                for frame_type, frame_payload in frames:
                    if frame_payload:
                        try:
                            return decode_json_payload(frame_payload)
                        except:
                            pass
            time.sleep(0.01)
        
        # Return empty status on timeout
        return {}
    
    def _log_trial(self, store: EventStoreJSONL, trial: Trial) -> None:
        """Log trial to event store."""
        event = {
            'event_type': 'trial_complete',
            'trial_id': trial.trial_id,
            'tg_ns': trial.attack.tg_ns,
            'delay_ns': trial.attack.delay_ns,
            'outcome': trial.outcome.value if trial.outcome else None,
            'trigger_seen': trial.observation.trigger_seen if trial.observation else False,
            'trigger_cleared': trial.observation.trigger_cleared if trial.observation else False,
            'led_state': trial.observation.led_state if trial.observation else None
        }
        store.append(event)
        store.flush()
    
    def _print_trial_result(self, trial: Trial) -> None:
        """Print trial result with Russian labels."""
        outcome_icons = {
            Outcome.SUCCESS: "✅",
            Outcome.NO_EFFECT: "➖",
            Outcome.HANG: "🛑",
            Outcome.ERROR: "⚠️"
        }
        
        icon = outcome_icons.get(trial.outcome, "❓")
        outcome_str = trial.outcome.value if trial.outcome else "Неизвестно"
        
        print(f"{icon} Испытание #{trial.trial_id}: Tg={trial.attack.tg_ns}нс, "
              f"Delay={trial.attack.delay_ns}нс → {outcome_str}")
