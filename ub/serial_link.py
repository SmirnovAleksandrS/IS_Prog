"""
Minimal pyserial wrapper for UART communication.
Russian logging messages, fails loudly on errors.
"""

import serial
import time
from typing import Optional


class SerialLink:
    """Context manager for serial port communication."""
    
    def __init__(self, port: str, baudrate: int = 115200, timeout_s: float = 0.5):
        """
        Initialize serial link.
        
        Args:
            port: Serial port name (e.g., "COM5" or "/dev/ttyUSB0")
            baudrate: Baud rate
            timeout_s: Read timeout in seconds
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout_s = timeout_s
        self._serial: Optional[serial.Serial] = None
    
    def __enter__(self):
        """Open the serial port."""
        print(f"🔌 Открыт порт {self.port} @ {self.baudrate} бод")
        self._serial = serial.Serial(
            port=self.port,
            baudrate=self.baudrate,
            timeout=self.timeout_s,
            write_timeout=1.0
        )
        # Clear buffers
        self._serial.reset_input_buffer()
        self._serial.reset_output_buffer()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Close the serial port."""
        if self._serial and self._serial.is_open:
            self._serial.close()
            print(f"🔌 Порт {self.port} закрыт")
    
    def write(self, data: bytes) -> None:
        """
        Write bytes to serial port.
        
        Args:
            data: Bytes to write
        
        Raises:
            RuntimeError: If serial port is not open
            serial.SerialException: On write error
        """
        if not self._serial or not self._serial.is_open:
            raise RuntimeError("Порт не открыт")
        
        self._serial.write(data)
        self._serial.flush()
    
    def read(self, n: int) -> bytes:
        """
        Read up to n bytes from serial port (blocking up to timeout).
        
        Args:
            n: Maximum number of bytes to read
        
        Returns:
            Bytes read (may be less than n if timeout occurs)
        
        Raises:
            RuntimeError: If serial port is not open
        """
        if not self._serial or not self._serial.is_open:
            raise RuntimeError("Порт не открыт")
        
        data = self._serial.read(n)
        return data
    
    def read_available(self) -> bytes:
        """
        Read all available bytes without blocking.
        
        Returns:
            All bytes currently in receive buffer
        """
        if not self._serial or not self._serial.is_open:
            raise RuntimeError("Порт не открыт")
        
        available = self._serial.in_waiting
        if available > 0:
            return self._serial.read(available)
        return b''
    
    def flush_input(self) -> None:
        """Flush input buffer."""
        if self._serial and self._serial.is_open:
            self._serial.reset_input_buffer()
