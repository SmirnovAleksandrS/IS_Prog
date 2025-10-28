"""
Research-style persistence: JSONL event store with optional SQLite export.
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any
import sqlite3


class EventStoreJSONL:
    """Simple JSONL event logger."""
    
    def __init__(self, path: str):
        """
        Initialize JSONL event store.
        
        Args:
            path: Path to JSONL file
        """
        self.path = Path(path)
        # Create parent directories if needed
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._file = None
    
    def __enter__(self):
        """Open file for appending."""
        self._file = open(self.path, 'a', encoding='utf-8')
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Close file."""
        if self._file:
            self._file.close()
    
    def append(self, obj: dict) -> None:
        """
        Append an event to the log.
        
        Args:
            obj: Dictionary to log (will be JSON-serialized)
        """
        if not self._file:
            raise RuntimeError("Event store not opened (use context manager)")
        
        # Add timestamp
        event = {
            'timestamp': datetime.now().isoformat(),
            **obj
        }
        
        # Write JSON line
        self._file.write(json.dumps(event, ensure_ascii=False) + '\n')
    
    def flush(self) -> None:
        """Flush file buffer."""
        if self._file:
            self._file.flush()


def export_to_sqlite(jsonl_path: str, sqlite_path: str) -> None:
    """
    Export JSONL events to SQLite database.
    
    Creates a simple 'trials' table with flattened fields.
    
    Args:
        jsonl_path: Path to JSONL file
        sqlite_path: Path to SQLite database file
    """
    # Read JSONL
    events = []
    with open(jsonl_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                events.append(json.loads(line))
    
    if not events:
        print("⚠️  Нет событий для экспорта")
        return
    
    # Create SQLite database
    Path(sqlite_path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(sqlite_path)
    cursor = conn.cursor()
    
    # Create table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS trials (
            trial_id INTEGER PRIMARY KEY,
            timestamp TEXT,
            tg_ns INTEGER,
            delay_ns INTEGER,
            outcome TEXT,
            trigger_seen INTEGER,
            trigger_cleared INTEGER,
            led_state TEXT
        )
    ''')
    
    # Insert events
    for event in events:
        if event.get('event_type') == 'trial_complete':
            cursor.execute('''
                INSERT OR REPLACE INTO trials 
                (trial_id, timestamp, tg_ns, delay_ns, outcome, 
                 trigger_seen, trigger_cleared, led_state)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                event.get('trial_id'),
                event.get('timestamp'),
                event.get('tg_ns'),
                event.get('delay_ns'),
                event.get('outcome'),
                1 if event.get('trigger_seen') else 0,
                1 if event.get('trigger_cleared') else 0,
                event.get('led_state')
            ))
    
    conn.commit()
    conn.close()
    print(f"✅ Экспортировано {len(events)} событий в {sqlite_path}")


def export_to_csv(jsonl_path: str, csv_path: str) -> None:
    """
    Export JSONL events to CSV.
    
    Args:
        jsonl_path: Path to JSONL file
        csv_path: Path to CSV file
    """
    import csv
    
    # Read JSONL
    events = []
    with open(jsonl_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                event = json.loads(line)
                if event.get('event_type') == 'trial_complete':
                    events.append(event)
    
    if not events:
        print("⚠️  Нет данных для экспорта")
        return
    
    # Write CSV
    Path(csv_path).parent.mkdir(parents=True, exist_ok=True)
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        fieldnames = ['trial_id', 'timestamp', 'tg_ns', 'delay_ns', 'outcome', 
                      'trigger_seen', 'trigger_cleared', 'led_state']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        
        for event in events:
            writer.writerow({
                'trial_id': event.get('trial_id'),
                'timestamp': event.get('timestamp'),
                'tg_ns': event.get('tg_ns'),
                'delay_ns': event.get('delay_ns'),
                'outcome': event.get('outcome'),
                'trigger_seen': event.get('trigger_seen'),
                'trigger_cleared': event.get('trigger_cleared'),
                'led_state': event.get('led_state')
            })
    
    print(f"✅ Экспортировано {len(events)} испытаний в {csv_path}")
