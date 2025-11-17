#!/usr/bin/env python3
"""
Test script to validate Arduino firmware protocol implementation.
Run this after uploading firmware to Arduino to test communication.
"""

import sys
import time
import json
from pathlib import Path

# Add parent directory to path to import ub modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from ub.protocol import MessageType, encode_frame, decode_stream, encode_json_payload, decode_json_payload
from ub.serial_link import SerialLink


def test_ping(link: SerialLink):
    """Test PING/PONG communication."""
    print("🧪 Testing PING/PONG...")
    
    frame = encode_frame(MessageType.PING, b'')
    link.write(frame)
    
    time.sleep(0.1)
    
    buffer = bytearray()
    data = link.read_available()
    if data:
        buffer.extend(data)
        frames = decode_stream(buffer)
        for msg_type, payload in frames:
            if msg_type == MessageType.PONG:
                print("✅ PING/PONG successful")
                return True
    
    print("❌ PING/PONG failed")
    return False


def test_set_attack(link: SerialLink):
    """Test SET_ATTACK command."""
    print("🧪 Testing SET_ATTACK...")
    
    attack_params = {
        "mode": "CLOCK_GLITCH",
        "clock_impl": "COMPRESS",
        "tg_ns": 64,
        "delay_ns": 250
    }
    
    payload = encode_json_payload(attack_params)
    frame = encode_frame(MessageType.SET_ATTACK, payload)
    link.write(frame)
    
    time.sleep(0.1)
    
    buffer = bytearray()
    data = link.read_available()
    if data:
        buffer.extend(data)
        frames = decode_stream(buffer)
        for msg_type, payload in frames:
            if msg_type == MessageType.ACK:
                print("✅ SET_ATTACK successful")
                return True
            elif msg_type == MessageType.NACK:
                print("❌ SET_ATTACK failed (NACK received)")
                return False
    
    print("❌ SET_ATTACK failed (no response)")
    return False


def test_arm_triggers(link: SerialLink):
    """Test ARM_TRIGGERS command."""
    print("🧪 Testing ARM_TRIGGERS...")
    
    trigger_params = {
        "kind": "GPIO_LEVEL",
        "edge": "rising",
        "timeout_ms": 200
    }
    
    payload = encode_json_payload(trigger_params)
    frame = encode_frame(MessageType.ARM_TRIGGERS, payload)
    link.write(frame)
    
    time.sleep(0.1)
    
    buffer = bytearray()
    data = link.read_available()
    if data:
        buffer.extend(data)
        frames = decode_stream(buffer)
        for msg_type, payload in frames:
            if msg_type == MessageType.ACK:
                print("✅ ARM_TRIGGERS successful")
                return True
            elif msg_type == MessageType.NACK:
                print("❌ ARM_TRIGGERS failed (NACK received)")
                return False
    
    print("❌ ARM_TRIGGERS failed (no response)")
    return False


def test_fire(link: SerialLink):
    """Test FIRE command."""
    print("🧪 Testing FIRE...")
    
    frame = encode_frame(MessageType.FIRE, b'')
    link.write(frame)
    
    time.sleep(0.1)
    
    buffer = bytearray()
    data = link.read_available()
    if data:
        buffer.extend(data)
        frames = decode_stream(buffer)
        for msg_type, payload in frames:
            if msg_type == MessageType.ACK:
                print("✅ FIRE successful")
                return True
            elif msg_type == MessageType.NACK:
                print("❌ FIRE failed (NACK received)")
                return False
    
    print("❌ FIRE failed (no response)")
    return False


def test_read_status(link: SerialLink):
    """Test READ_STATUS command."""
    print("🧪 Testing READ_STATUS...")
    
    frame = encode_frame(MessageType.READ_STATUS, b'')
    link.write(frame)
    
    time.sleep(0.2)
    
    buffer = bytearray()
    data = link.read_available()
    if data:
        buffer.extend(data)
        frames = decode_stream(buffer)
        for msg_type, payload in frames:
            if msg_type == MessageType.READ_STATUS:
                try:
                    status = decode_json_payload(payload)
                    print(f"✅ READ_STATUS successful: {json.dumps(status, indent=2)}")
                    
                    # Validate expected fields
                    required_fields = ['trigger_seen', 'trigger_cleared', 'led_state', 'hang', 'notes']
                    for field in required_fields:
                        if field not in status:
                            print(f"⚠️  Warning: Missing field '{field}' in status")
                    
                    return True
                except Exception as e:
                    print(f"❌ READ_STATUS failed (invalid JSON): {e}")
                    return False
    
    print("❌ READ_STATUS failed (no response)")
    return False


def test_soft_reset(link: SerialLink):
    """Test SOFT_RESET command."""
    print("🧪 Testing SOFT_RESET...")
    
    frame = encode_frame(MessageType.SOFT_RESET, b'')
    link.write(frame)
    
    time.sleep(0.1)
    
    buffer = bytearray()
    data = link.read_available()
    if data:
        buffer.extend(data)
        frames = decode_stream(buffer)
        for msg_type, payload in frames:
            if msg_type == MessageType.ACK:
                print("✅ SOFT_RESET successful")
                return True
    
    print("❌ SOFT_RESET failed")
    return False


def test_hard_reset(link: SerialLink):
    """Test HARD_RESET command."""
    print("🧪 Testing HARD_RESET...")
    
    frame = encode_frame(MessageType.HARD_RESET, b'')
    link.write(frame)
    
    time.sleep(0.1)
    
    buffer = bytearray()
    data = link.read_available()
    if data:
        buffer.extend(data)
        frames = decode_stream(buffer)
        for msg_type, payload in frames:
            if msg_type == MessageType.ACK:
                print("✅ HARD_RESET successful")
                return True
    
    print("❌ HARD_RESET failed")
    return False


def main():
    """Run all protocol tests."""
    print("=" * 60)
    print("Arduino Firmware Protocol Test")
    print("=" * 60)
    
    # Get serial port from user
    port = input("Enter Arduino COM port (e.g., COM10): ").strip()
    if not port:
        print("❌ No port specified")
        return
    
    print(f"\n🔌 Connecting to {port}...")
    
    try:
        with SerialLink(port, 115200, 0.5) as link:
            time.sleep(2)  # Wait for Arduino reset after serial connection
            
            print("\n" + "=" * 60)
            print("Running Tests")
            print("=" * 60 + "\n")
            
            results = []
            
            # Test sequence
            results.append(("PING/PONG", test_ping(link)))
            time.sleep(0.2)
            
            results.append(("HARD_RESET", test_hard_reset(link)))
            time.sleep(0.2)
            
            results.append(("SET_ATTACK", test_set_attack(link)))
            time.sleep(0.2)
            
            results.append(("ARM_TRIGGERS", test_arm_triggers(link)))
            time.sleep(0.2)
            
            results.append(("FIRE", test_fire(link)))
            time.sleep(0.2)
            
            results.append(("READ_STATUS", test_read_status(link)))
            time.sleep(0.2)
            
            results.append(("SOFT_RESET", test_soft_reset(link)))
            time.sleep(0.2)
            
            # Summary
            print("\n" + "=" * 60)
            print("Test Summary")
            print("=" * 60)
            
            passed = sum(1 for _, result in results if result)
            total = len(results)
            
            for test_name, result in results:
                status = "✅ PASS" if result else "❌ FAIL"
                print(f"{test_name:20s} {status}")
            
            print("-" * 60)
            print(f"Total: {passed}/{total} tests passed")
            
            if passed == total:
                print("\n🎉 All tests passed! Firmware is ready for use.")
            else:
                print(f"\n⚠️  {total - passed} test(s) failed. Check firmware implementation.")
    
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
