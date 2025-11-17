# Arduino Test Firmware

This directory contains the test firmware for Arduino Nano that simulates a glitch attack hardware backend for the Python glitch controller framework.

## Overview

The firmware implements a complete UART protocol handler that:
- Receives commands from the Python controller (SET_ATTACK, ARM_TRIGGERS, FIRE, etc.)
- Responds with ACK/NACK acknowledgments
- Simulates realistic glitch attack outcomes
- Provides JSON status responses
- Uses the built-in LED for visual feedback

## Hardware Requirements

- **Arduino Nano** (ATmega328P)
- USB cable for programming and serial communication
- No additional hardware required (test firmware only)

## Software Requirements

- **PlatformIO** (for building and uploading firmware)
  - Install via VS Code extension, or
  - Install CLI: `pip install platformio`
- **Python 3.8+** (for testing the protocol)
- Dependencies from main project `requirements.txt`

## Building the Firmware

### Using PlatformIO CLI

```bash
# Navigate to arduino directory
cd arduino

# Install dependencies (ArduinoJson library)
platformio lib install

# Build the firmware
platformio run

# Upload to Arduino (adjust COM port as needed)
platformio run --target upload

# Open serial monitor to see activity
platformio device monitor
```

### Using PlatformIO IDE (VS Code)

1. Open the `arduino` folder in VS Code
2. PlatformIO should auto-detect the project
3. Click "Build" (checkmark icon in bottom toolbar)
4. Click "Upload" (arrow icon) to flash to Arduino
5. Click "Serial Monitor" (plug icon) to view communication

## Configuration

### platformio.ini

The configuration is already set up for Arduino Nano:

```ini
[env:nanoatmega328]
platform = atmelavr
board = nanoatmega328
framework = arduino
monitor_speed = 115200
lib_deps = 
    bblanchon/ArduinoJson@^7.0.0
```

### Serial Port

Default baud rate: **115200**

Find your Arduino's COM port:
- **Windows**: Check Device Manager → Ports (COM & LPT)
- **Linux**: Usually `/dev/ttyUSB0` or `/dev/ttyACM0`
- **macOS**: Usually `/dev/cu.usbserial-*`

Update the port in the main `config.yaml`:

```yaml
serial:
  port: "COM10"  # Change to your port
  baudrate: 115200
```

## Testing the Firmware

### Quick Protocol Test

After uploading the firmware, run the protocol test script:

```bash
# From the arduino directory
python test_protocol.py
```

This will:
1. Test PING/PONG communication
2. Test all command handlers (SET_ATTACK, ARM_TRIGGERS, FIRE, etc.)
3. Verify JSON response parsing
4. Display test results

### Full Integration Test

Run a minimal campaign from the main project directory:

```bash
# Navigate to project root
cd ..

# Edit config.yaml to set correct COM port and reduce trials
# Set max_trials: 10 for quick test

# Run the campaign
python -m ub.cli run --config config.yaml
```

Expected output:
- All trials complete without timeout errors
- `events.jsonl` created with varied outcomes
- Success/No Effect/Hang outcomes distributed based on parameters

## LED Indicators

The built-in LED (D13) shows firmware status:

| Pattern | Meaning |
|---------|---------|
| **OFF** | Idle, waiting for commands |
| **ON** | Success outcome (after FIRE) |
| **Slow blink** (500ms) | Triggers armed, waiting |
| **Fast blink** (100ms) | Hang outcome simulated |

## Protocol Details

### Frame Format

```
[SOF=0x7E][TYPE:1][LEN:1][PAYLOAD:LEN][CRC32:4]
```

- **SOF**: Start of Frame marker (0x7E)
- **TYPE**: MessageType enum (0x01-0x06, 0x10-0x11, 0x20-0x21)
- **LEN**: Payload length (0-255)
- **PAYLOAD**: Message payload (often JSON)
- **CRC32**: Checksum over TYPE+LEN+PAYLOAD (little-endian)

### Message Types

| Type | Value | Direction | Purpose |
|------|-------|-----------|---------|
| SET_ATTACK | 0x01 | PC → Arduino | Configure attack parameters |
| ARM_TRIGGERS | 0x02 | PC → Arduino | Arm trigger detection |
| FIRE | 0x03 | PC → Arduino | Execute glitch attack |
| READ_STATUS | 0x04 | PC → Arduino | Query current status |
| SOFT_RESET | 0x05 | PC → Arduino | Reset flags only |
| HARD_RESET | 0x06 | PC → Arduino | Full state reset |
| ACK | 0x10 | Arduino → PC | Command acknowledged |
| NACK | 0x11 | Arduino → PC | Command rejected |
| PING | 0x20 | PC → Arduino | Connectivity check |
| PONG | 0x21 | Arduino → PC | Response to PING |

### JSON Payloads

**SET_ATTACK:**
```json
{
  "mode": "CLOCK_GLITCH",
  "clock_impl": "COMPRESS",
  "tg_ns": 64,
  "delay_ns": 250
}
```

**ARM_TRIGGERS:**
```json
{
  "kind": "GPIO_LEVEL",
  "edge": "rising",
  "timeout_ms": 200
}
```

**READ_STATUS Response:**
```json
{
  "trigger_seen": true,
  "trigger_cleared": true,
  "led_state": "ON",
  "hang": false,
  "notes": "Trial #42 complete"
}
```

## Outcome Simulation Logic

The firmware generates deterministic but varied outcomes:

| Condition | Outcome | LED State |
|-----------|---------|-----------|
| `tg_ns < 30` AND `delay_ns % 100 == 0` | **Success** | ON |
| `tg_ns > 80` | **No Effect** | OFF |
| `delay_ns > 4500` | **No Effect** | OFF |
| `trial_counter % 10 == 7` | **Hang** | Fast blink |
| Otherwise | **Random (weighted)** | Varies |

This creates a realistic gradient for heatmap visualization.

## Troubleshooting

### Upload Failed

- Check USB cable connection
- Verify correct COM port selected
- Try pressing reset button on Arduino before upload
- Close any serial monitors (only one program can access serial port)

### No Response from Firmware

- Verify baud rate is 115200
- Check that firmware uploaded successfully (LED should not be blinking on boot)
- Try HARD_RESET command
- Re-upload firmware

### CRC Errors

- Python and Arduino must use same CRC32 algorithm
- Verify ArduinoJson library is installed (v7.0.0 or higher)
- Check serial port stability (try different USB port/cable)

### JSON Parsing Errors

- Verify JSON payload format matches expected structure
- Check payload length doesn't exceed 255 bytes
- Monitor serial output for debug information

## Development Notes

### Memory Usage

Arduino Nano (ATmega328P) has limited resources:
- **Flash**: 32 KB (code storage)
- **SRAM**: 2 KB (runtime memory)

Current usage estimate:
- CRC32 table: ~1 KB (Flash)
- Buffers: ~600 bytes (SRAM)
- ArduinoJson: ~512 bytes (SRAM)
- Other: ~500 bytes (SRAM)

**Total**: ~1.7 KB SRAM (fits comfortably)

### Extending the Firmware

To add new message handlers:

1. Add message type to `MessageType` enum
2. Create handler function: `void handle_xyz(const uint8_t* payload, uint8_t len)`
3. Add case to switch statement in `process_frame()`
4. Update Python `ub/protocol.py` if needed

### Debugging

Enable verbose serial output by adding debug prints:

```cpp
Serial.print("DEBUG: ");
Serial.println("Message");
```

**Note**: Debug prints will interfere with protocol communication. Use only during development with Arduino disconnected from Python controller.

## Files

- **src/main.cpp**: Complete firmware implementation
- **platformio.ini**: PlatformIO project configuration
- **test_protocol.py**: Python protocol test script
- **README.md**: This file

## References

- Main specification: `../info/Spec.md`
- Python protocol implementation: `../ub/protocol.py`
- Python orchestrator: `../ub/orchestrator.py`
- Design document: `../.qoder/quests/arduino-glitch-generator-test.md`

## License

Same as parent project (MIT)
