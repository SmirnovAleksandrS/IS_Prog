#!/usr/bin/env python3
"""
Example: Manual trial execution with Arduino test firmware.

This demonstrates how to manually control the glitch attack flow
using the Arduino test firmware, useful for debugging and development.
"""

import sys
import time
from pathlib import Path

# Add parent directory to import ub modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from ub.protocol import MessageType, encode_frame, decode_stream, encode_json_payload, decode_json_payload
from ub.serial_link import SerialLink


def wait_for_ack(link: SerialLink, timeout: float = 1.0) -> bool:
    """Wait for ACK response from Arduino."""
    start = time.time()
    buffer = bytearray()
    
    while time.time() - start < timeout:
        data = link.read_available()
        if data:
            buffer.extend(data)
            frames = decode_stream(buffer)
            for msg_type, payload in frames:
                if msg_type == MessageType.ACK:
                    return True
                elif msg_type == MessageType.NACK:
                    print("⚠️  Received NACK")
                    return False
        time.sleep(0.01)
    
    print("⚠️  Timeout waiting for ACK")
    return False


def read_status(link: SerialLink) -> dict:
    """Read current status from Arduino."""
    frame = encode_frame(MessageType.READ_STATUS, b'')
    link.write(frame)
    
    time.sleep(0.1)
    
    buffer = bytearray()
    data = link.read_available()
    if data:
        buffer.extend(data)
        frames = decode_stream(buffer)
        for msg_type, payload in frames:
            if msg_type == MessageType.READ_STATUS:
                return decode_json_payload(payload)
    
    return {}


def run_single_trial(link: SerialLink, tg_ns: int, delay_ns: int):
    """Execute a single glitch trial."""
    
    print(f"\n{'='*60}")
    print(f"Trial: Tg={tg_ns}нс, Delay={delay_ns}нс")
    print('='*60)
    
    # Step 1: Configure attack
    print("1️⃣  Setting attack parameters...")
    attack_params = {
        "mode": "CLOCK_GLITCH",
        "clock_impl": "COMPRESS",
        "tg_ns": tg_ns,
        "delay_ns": delay_ns
    }
    payload = encode_json_payload(attack_params)
    frame = encode_frame(MessageType.SET_ATTACK, payload)
    link.write(frame)
    
    if not wait_for_ack(link):
        print("❌ Failed to set attack")
        return None
    print("   ✅ Attack configured")
    
    # Step 2: Arm triggers
    print("2️⃣  Arming triggers...")
    trigger_params = {
        "kind": "GPIO_LEVEL",
        "edge": "rising",
        "timeout_ms": 200
    }
    payload = encode_json_payload(trigger_params)
    frame = encode_frame(MessageType.ARM_TRIGGERS, payload)
    link.write(frame)
    
    if not wait_for_ack(link):
        print("❌ Failed to arm triggers")
        return None
    print("   ✅ Triggers armed")
    
    # Step 3: Wait a bit for trigger simulation
    print("3️⃣  Waiting for trigger...")
    time.sleep(0.15)  # Trigger fires after 50-150ms
    
    # Step 4: Fire glitch
    print("4️⃣  Firing glitch...")
    frame = encode_frame(MessageType.FIRE, b'')
    link.write(frame)
    
    if not wait_for_ack(link):
        print("❌ Failed to fire")
        return None
    print("   ✅ Glitch fired")
    
    # Step 5: Read status
    print("5️⃣  Reading status...")
    time.sleep(0.05)
    status = read_status(link)
    
    if status:
        print("   ✅ Status received:")
        print(f"      • Trigger seen: {status.get('trigger_seen', False)}")
        print(f"      • Trigger cleared: {status.get('trigger_cleared', False)}")
        print(f"      • LED state: {status.get('led_state', 'UNKNOWN')}")
        print(f"      • Hang: {status.get('hang', False)}")
        print(f"      • Notes: {status.get('notes', 'N/A')}")
        
        # Classify outcome
        if status.get('trigger_seen') and status.get('trigger_cleared'):
            outcome = "✅ SUCCESS"
        elif status.get('hang'):
            outcome = "🛑 HANG"
        else:
            outcome = "➖ NO EFFECT"
        
        print(f"\n   📊 Outcome: {outcome}")
        return outcome
    else:
        print("   ❌ No status received")
        return None
    
    # Step 6: Soft reset for next trial
    print("6️⃣  Soft reset...")
    frame = encode_frame(MessageType.SOFT_RESET, b'')
    link.write(frame)
    wait_for_ack(link)


def main():
    """Run example manual trials."""
    
    print("="*60)
    print("Arduino Firmware - Manual Trial Example")
    print("="*60)
    
    # Get COM port
    port = input("\nEnter Arduino COM port (e.g., COM10): ").strip()
    if not port:
        print("❌ No port specified")
        return
    
    print(f"\n🔌 Connecting to {port}...")
    
    try:
        with SerialLink(port, 115200, 0.5) as link:
            time.sleep(2)  # Wait for Arduino reset
            
            # Test connectivity
            print("🏓 Testing connection (PING)...")
            frame = encode_frame(MessageType.PING, b'')
            link.write(frame)
            time.sleep(0.1)
            
            buffer = bytearray()
            data = link.read_available()
            if data:
                buffer.extend(data)
                frames = decode_stream(buffer)
                pong_received = any(msg_type == MessageType.PONG for msg_type, _ in frames)
                if pong_received:
                    print("✅ Connection successful (PONG received)\n")
                else:
                    print("❌ No PONG received\n")
                    return
            else:
                print("❌ No response\n")
                return
            
            # Hard reset to clear state
            print("🔄 Performing hard reset...")
            frame = encode_frame(MessageType.HARD_RESET, b'')
            link.write(frame)
            wait_for_ack(link)
            time.sleep(0.1)
            
            # Run example trials with different parameters
            trials = [
                (64, 100),    # Should show no effect
                (28, 200),    # Higher success chance
                (20, 100),    # High success chance (< 30ns, delay % 100 == 0)
                (100, 250),   # Should show no effect (> 80ns)
                (24, 5000),   # Should show no effect (delay > 4500)
            ]
            
            results = []
            for tg_ns, delay_ns in trials:
                outcome = run_single_trial(link, tg_ns, delay_ns)
                results.append((tg_ns, delay_ns, outcome))
                time.sleep(0.5)  # Pause between trials
            
            # Summary
            print("\n" + "="*60)
            print("Summary")
            print("="*60)
            
            for tg_ns, delay_ns, outcome in results:
                print(f"Tg={tg_ns:3d}нс, Delay={delay_ns:4d}нс → {outcome or 'ERROR'}")
            
            print("\n✨ Example complete!")
            print("\nNext steps:")
            print("  • Run full campaign: python -m ub.cli run --config config.yaml")
            print("  • Analyze results in runs/ directory")
            print("  • Generate heatmap: python -m ub.cli report --config config.yaml")
    
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
