"""
Simple framing layer for UART communication with the glitch stand.
Frame format: [SOF=0x7E][TYPE:1][LEN:1][PAYLOAD:LEN][CRC32:4]
"""

from enum import IntEnum
import binascii
import struct
import json


class MessageType(IntEnum):
    """Message types for controller-stand communication."""
    SET_ATTACK   = 0x01
    ARM_TRIGGERS = 0x02
    FIRE         = 0x03
    READ_STATUS  = 0x04
    SOFT_RESET   = 0x05
    HARD_RESET   = 0x06

    ACK          = 0x10
    NACK         = 0x11
    PING         = 0x20
    PONG         = 0x21

    GET_CAPS     = 0x30
    TRACE_DUMP   = 0x31


SOF = 0x7E


def encode_frame(msg_type: MessageType, payload: bytes) -> bytes:
    """
    Encode a message into a frame.
    
    Args:
        msg_type: Type of message
        payload: Payload bytes (empty bytes() if no payload)
    
    Returns:
        Complete frame with SOF, type, length, payload, and CRC32
    """
    length = len(payload)
    if length > 255:
        raise ValueError(f"Payload too long: {length} bytes (max 255)")
    
    # Build message without CRC: TYPE + LEN + PAYLOAD
    msg_without_crc = struct.pack('B', msg_type) + struct.pack('B', length) + payload
    
    # Calculate CRC32 over TYPE+LEN+PAYLOAD
    crc = binascii.crc32(msg_without_crc) & 0xFFFFFFFF
    
    # Build complete frame: SOF + TYPE + LEN + PAYLOAD + CRC32 (little-endian)
    frame = struct.pack('B', SOF) + msg_without_crc + struct.pack('<I', crc)
    
    return frame


def decode_stream(buffer: bytearray) -> list[tuple[MessageType, bytes]]:
    """
    Decode frames from a buffer, extracting complete messages.
    
    Args:
        buffer: Input buffer (will be modified to remove processed frames)
    
    Returns:
        List of (MessageType, payload) tuples for complete valid frames
    """
    frames = []
    
    while True:
        # Find SOF
        try:
            sof_idx = buffer.index(SOF)
        except ValueError:
            # No SOF found, clear buffer up to end
            buffer.clear()
            break
        
        # Remove everything before SOF
        if sof_idx > 0:
            del buffer[:sof_idx]
        
        # Check if we have enough bytes for header (SOF + TYPE + LEN)
        if len(buffer) < 3:
            break
        
        msg_type = buffer[1]
        length = buffer[2]
        
        # Check if we have the full frame (SOF + TYPE + LEN + PAYLOAD + CRC32)
        frame_size = 1 + 1 + 1 + length + 4
        if len(buffer) < frame_size:
            break
        
        # Extract the frame
        frame = bytes(buffer[:frame_size])
        
        # Verify CRC32
        msg_without_crc = frame[1:3+length]  # TYPE + LEN + PAYLOAD
        expected_crc = binascii.crc32(msg_without_crc) & 0xFFFFFFFF
        actual_crc = struct.unpack('<I', frame[3+length:3+length+4])[0]
        
        if expected_crc == actual_crc:
            # Valid frame
            payload = frame[3:3+length]
            try:
                frames.append((MessageType(msg_type), payload))
            except ValueError:
                # Unknown message type, skip
                pass
        
        # Remove processed frame from buffer
        del buffer[:frame_size]
    
    return frames


def encode_json_payload(obj: dict) -> bytes:
    """Encode a dictionary as JSON bytes."""
    return json.dumps(obj, ensure_ascii=False).encode('utf-8')


def decode_json_payload(payload: bytes) -> dict:
    """Decode JSON bytes to dictionary."""
    return json.loads(payload.decode('utf-8'))
