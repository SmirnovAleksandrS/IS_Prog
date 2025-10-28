"""
CLI for the glitch controller framework.
All messages in Russian as per spec.
"""

import argparse
import sys
import yaml
from pathlib import Path
from .orchestrator import Orchestrator
from .storage import export_to_sqlite, export_to_csv
from .viz import save_heatmap, save_timeline


def load_config(config_path: str) -> dict:
    """Load YAML configuration file."""
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        return config
    except FileNotFoundError:
        print(f"❌ Файл конфигурации не найден: {config_path}")
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"❌ Ошибка парсинга YAML: {e}")
        sys.exit(1)


def cmd_run(args):
    """Run a new campaign."""
    config = load_config(args.config)
    
    print("=" * 60)
    print(f"🚀 ЗАПУСК КАМПАНИИ: {config['app']['run_name']}")
    print("=" * 60)
    
    orchestrator = Orchestrator(config)
    
    try:
        orchestrator.run()
    except KeyboardInterrupt:
        print("\n⚠️  Кампания прервана пользователем")
    except Exception as e:
        print(f"\n❌ Ошибка выполнения: {e}")
        raise
    
    print("\n" + "=" * 60)
    print("📊 КАМПАНИЯ ЗАВЕРШЕНА")
    print("=" * 60)


def cmd_resume(args):
    """Resume an existing campaign."""
    # For now, just call run (JSONL append mode)
    print("⏯️  Возобновление кампании (режим добавления)")
    cmd_run(args)


def cmd_report(args):
    """Generate reports and visualizations."""
    config = load_config(args.config)
    
    print("=" * 60)
    print(f"📊 ГЕНЕРАЦИЯ ОТЧЕТОВ: {config['app']['run_name']}")
    print("=" * 60)
    
    jsonl_path = config['storage']['jsonl_path']
    sqlite_path = config['storage'].get('sqlite_path')
    viz_config = config.get('viz', {})
    
    # Check if JSONL exists
    if not Path(jsonl_path).exists():
        print(f"❌ Файл событий не найден: {jsonl_path}")
        sys.exit(1)
    
    # Export to SQLite
    if sqlite_path:
        print(f"\n📦 Экспорт в SQLite: {sqlite_path}")
        export_to_sqlite(jsonl_path, sqlite_path)
    
    # Export to CSV
    csv_path = str(Path(jsonl_path).with_suffix('.csv'))
    print(f"\n📦 Экспорт в CSV: {csv_path}")
    export_to_csv(jsonl_path, csv_path)
    
    # Generate visualizations
    if viz_config.get('make_heatmap', False):
        print("\n📊 Генерация тепловых карт...")
        
        # Load trials from JSONL
        import json
        from .model import Trial, AttackSpec, TriggerSpec, Observation, Outcome, AttackMode, ClockImpl, TriggerKind
        
        trials = []
        with open(jsonl_path, 'r', encoding='utf-8') as f:
            for line in f:
                if line.strip():
                    event = json.loads(line)
                    if event.get('event_type') == 'trial_complete':
                        # Reconstruct trial
                        trial = Trial(
                            trial_id=event['trial_id'],
                            attack=AttackSpec(
                                mode=AttackMode.CLOCK_GLITCH,
                                clock_impl=ClockImpl.COMPRESS,
                                tg_ns=event['tg_ns'],
                                delay_ns=event['delay_ns']
                            ),
                            trigger=TriggerSpec(
                                kind=TriggerKind.GPIO_LEVEL,
                                edge="rising"
                            ),
                            observation=Observation(
                                raw_status={},
                                trigger_seen=event.get('trigger_seen', False),
                                trigger_cleared=event.get('trigger_cleared', False),
                                led_state=event.get('led_state')
                            ),
                            outcome=Outcome(event['outcome']) if event.get('outcome') else None
                        )
                        trials.append(trial)
        
        viz_dir = viz_config.get('output_dir', './viz')
        metric = viz_config.get('heatmap_metric', 'success_rate')
        
        save_heatmap(trials, viz_dir, metric)
        save_timeline(trials, viz_dir)
    
    print("\n" + "=" * 60)
    print("✅ ОТЧЕТЫ СГЕНЕРИРОВАНЫ")
    print("=" * 60)


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='Управляющий блок для стенда глитчинга AVR',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры:
  %(prog)s run --config config.yaml          # Запустить кампанию
  %(prog)s resume --config config.yaml       # Возобновить кампанию
  %(prog)s report --config config.yaml       # Сгенерировать отчеты
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Команда')
    
    # Run command
    parser_run = subparsers.add_parser('run', help='Запустить новую кампанию')
    parser_run.add_argument('--config', required=True, help='Путь к файлу конфигурации')
    parser_run.set_defaults(func=cmd_run)
    
    # Resume command
    parser_resume = subparsers.add_parser('resume', help='Возобновить кампанию')
    parser_resume.add_argument('--config', required=True, help='Путь к файлу конфигурации')
    parser_resume.set_defaults(func=cmd_resume)
    
    # Report command
    parser_report = subparsers.add_parser('report', help='Сгенерировать отчеты и визуализации')
    parser_report.add_argument('--config', required=True, help='Путь к файлу конфигурации')
    parser_report.set_defaults(func=cmd_report)
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    args.func(args)


if __name__ == '__main__':
    main()
