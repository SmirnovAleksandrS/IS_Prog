"""
Installation verification script.
Tests all core components without requiring hardware.
"""

import sys
sys.path.insert(0, '.')

print("=" * 70)
print("GLITCH CONTROLLER - VERIFICATION SCRIPT")
print("=" * 70)

# Test 1: Module imports
print("\n[1/6] Testing module imports...")
try:
    from ub import (
        Orchestrator, GridSearchStrategy, RandomSearchStrategy,
        MessageType, encode_frame, decode_stream,
        AttackSpec, TriggerSpec, Trial, Outcome
    )
    print("   ✅ All core modules imported successfully")
except ImportError as e:
    print(f"   ❌ Import failed: {e}")
    sys.exit(1)

# Test 2: Protocol encoding/decoding
print("\n[2/6] Testing protocol encoding/decoding...")
try:
    from ub.protocol import MessageType, encode_frame, decode_stream
    
    # Encode a frame
    payload = b'{"test": "data"}'
    frame = encode_frame(MessageType.SET_ATTACK, payload)
    
    # Decode the frame
    buffer = bytearray(frame)
    decoded = decode_stream(buffer)
    
    if len(decoded) == 1 and decoded[0][0] == MessageType.SET_ATTACK:
        print("   ✅ Protocol encoding/decoding works correctly")
    else:
        print("   ❌ Protocol decode mismatch")
        sys.exit(1)
except Exception as e:
    print(f"   ❌ Protocol test failed: {e}")
    sys.exit(1)

# Test 3: Strategy generation
print("\n[3/6] Testing attack strategy generation...")
try:
    from ub.strategy import GridSearchStrategy, StrategyConfig
    from ub.model import TriggerSpec, TriggerKind
    
    trigger = TriggerSpec(kind=TriggerKind.GPIO_LEVEL, edge="rising")
    strategy_cfg = StrategyConfig(
        name="grid",
        params={
            'tg_ns': [100, 80],
            'delay_ns': {'start': 0, 'stop': 100, 'step': 50},
            'repeats_per_point': 1
        }
    )
    
    strategy = GridSearchStrategy(strategy_cfg, trigger)
    attacks = strategy.propose([], n=3)
    
    if len(attacks) == 3:
        print(f"   ✅ Strategy generated {len(attacks)} attack points")
    else:
        print(f"   ❌ Expected 3 attacks, got {len(attacks)}")
        sys.exit(1)
except Exception as e:
    print(f"   ❌ Strategy test failed: {e}")
    sys.exit(1)

# Test 4: Outcome classification
print("\n[4/6] Testing outcome classification...")
try:
    from ub.observe import Evaluator
    from ub.model import Observation, Outcome
    
    evaluator = Evaluator()
    
    # Test success case
    obs = Observation(
        raw_status={},
        trigger_seen=True,
        trigger_cleared=True,
        led_state="ON"
    )
    outcome = evaluator.classify(obs)
    
    if outcome == Outcome.SUCCESS:
        print("   ✅ Outcome classification works correctly")
    else:
        print(f"   ❌ Expected SUCCESS, got {outcome}")
        sys.exit(1)
except Exception as e:
    print(f"   ❌ Classification test failed: {e}")
    sys.exit(1)

# Test 5: Storage (dry run)
print("\n[5/6] Testing storage system...")
try:
    from ub.storage import EventStoreJSONL
    import tempfile
    import os
    
    # Create temporary file
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.jsonl') as tmp:
        tmp_path = tmp.name
    
    try:
        # Test writing
        with EventStoreJSONL(tmp_path) as store:
            store.append({'test': 'event', 'trial_id': 1})
        
        # Test reading
        with open(tmp_path, 'r') as f:
            lines = f.readlines()
        
        if len(lines) == 1:
            print("   ✅ Storage system works correctly")
        else:
            print(f"   ❌ Expected 1 event, found {len(lines)}")
            sys.exit(1)
    finally:
        os.unlink(tmp_path)
except Exception as e:
    print(f"   ❌ Storage test failed: {e}")
    sys.exit(1)

# Test 6: Config loading
print("\n[6/6] Testing configuration loading...")
try:
    import yaml
    
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    required_keys = ['app', 'serial', 'protocol', 'campaign', 'storage', 'viz']
    missing = [k for k in required_keys if k not in config]
    
    if not missing:
        print("   ✅ Configuration file is valid")
    else:
        print(f"   ❌ Missing config sections: {missing}")
        sys.exit(1)
except Exception as e:
    print(f"   ❌ Config test failed: {e}")
    sys.exit(1)

# Final summary
print("\n" + "=" * 70)
print("✅ ALL TESTS PASSED!")
print("=" * 70)
print("\n📋 Available outcomes:", [o.value for o in Outcome])
print("📋 Available message types:", len(list(MessageType)), "types")
print("\n🎯 Framework is ready to use!")
print("\nNext steps:")
print("  1. Update config.yaml with your serial port")
print("  2. Run: python -m ub.cli run --config config.yaml")
print("  3. Generate reports: python -m ub.cli report --config config.yaml")
print("\n" + "=" * 70)
