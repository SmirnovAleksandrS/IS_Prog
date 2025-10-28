"""
Visualization tools with Russian labels.
Quick heatmaps and timelines for analysis.
"""

import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import numpy as np
from pathlib import Path
from typing import List
from collections import defaultdict
from .model import Trial, Outcome


def save_heatmap(trials: List[Trial], outdir: str, metric: str = "success_rate") -> None:
    """
    Generate and save a 2D heatmap of trial results.
    
    Args:
        trials: List of completed trials
        outdir: Output directory for PNG file
        metric: Metric to visualize ("success_rate", "hang_rate", "no_effect_rate")
    """
    if not trials:
        print("⚠️  Нет данных для визуализации")
        return
    
    # Create output directory
    Path(outdir).mkdir(parents=True, exist_ok=True)
    
    # Extract parameters and outcomes
    data = defaultdict(lambda: {'total': 0, 'success': 0, 'hang': 0, 'no_effect': 0})
    
    for trial in trials:
        if trial.outcome is None:
            continue
        
        key = (trial.attack.tg_ns, trial.attack.delay_ns)
        data[key]['total'] += 1
        
        if trial.outcome == Outcome.SUCCESS:
            data[key]['success'] += 1
        elif trial.outcome == Outcome.HANG:
            data[key]['hang'] += 1
        elif trial.outcome == Outcome.NO_EFFECT:
            data[key]['no_effect'] += 1
    
    # Build grid
    tg_values = sorted(set(k[0] for k in data.keys()))
    delay_values = sorted(set(k[1] for k in data.keys()))
    
    if not tg_values or not delay_values:
        print("⚠️  Недостаточно данных для построения тепловой карты")
        return
    
    # Create 2D array for heatmap
    grid = np.zeros((len(tg_values), len(delay_values)))
    
    for i, tg in enumerate(tg_values):
        for j, delay in enumerate(delay_values):
            key = (tg, delay)
            if key in data and data[key]['total'] > 0:
                if metric == "success_rate":
                    grid[i, j] = data[key]['success'] / data[key]['total']
                elif metric == "hang_rate":
                    grid[i, j] = data[key]['hang'] / data[key]['total']
                elif metric == "no_effect_rate":
                    grid[i, j] = data[key]['no_effect'] / data[key]['total']
            else:
                grid[i, j] = np.nan
    
    # Create figure
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Plot heatmap
    im = ax.imshow(grid, aspect='auto', cmap='RdYlGn', vmin=0, vmax=1, interpolation='nearest')
    
    # Labels in Russian
    metric_labels = {
        'success_rate': 'Доля успехов',
        'hang_rate': 'Доля зависаний',
        'no_effect_rate': 'Доля без эффекта'
    }
    
    ax.set_title(f'Тепловая карта: {metric_labels.get(metric, metric)}', fontsize=14, weight='bold')
    ax.set_xlabel('Задержка (нс)', fontsize=12)
    ax.set_ylabel('Tg (нс)', fontsize=12)
    
    # Set ticks
    ax.set_xticks(np.arange(len(delay_values)))
    ax.set_yticks(np.arange(len(tg_values)))
    ax.set_xticklabels(delay_values)
    ax.set_yticklabels(tg_values)
    
    # Rotate x labels if too many
    if len(delay_values) > 20:
        plt.setp(ax.get_xticklabels(), rotation=45, ha='right', rotation_mode='anchor')
    
    # Add colorbar
    cbar = plt.colorbar(im, ax=ax)
    cbar.set_label('Доля', fontsize=11)
    
    # Tight layout
    plt.tight_layout()
    
    # Save
    output_path = Path(outdir) / f'heatmap_{metric}.png'
    plt.savefig(output_path, dpi=150)
    plt.close()
    
    print(f"📊 Тепловая карта сохранена: {output_path}")


def save_timeline(trials: List[Trial], outdir: str) -> None:
    """
    Save a simple timeline plot of trial outcomes.
    
    Args:
        trials: List of completed trials
        outdir: Output directory for PNG file
    """
    if not trials:
        print("⚠️  Нет данных для визуализации")
        return
    
    # Create output directory
    Path(outdir).mkdir(parents=True, exist_ok=True)
    
    # Extract data
    trial_ids = []
    outcomes = []
    colors = []
    
    color_map = {
        Outcome.SUCCESS: 'green',
        Outcome.NO_EFFECT: 'gray',
        Outcome.HANG: 'red',
        Outcome.ERROR: 'orange'
    }
    
    for trial in trials:
        if trial.outcome:
            trial_ids.append(trial.trial_id)
            outcomes.append(trial.outcome.value)
            colors.append(color_map.get(trial.outcome, 'blue'))
    
    if not trial_ids:
        print("⚠️  Нет данных для построения временной диаграммы")
        return
    
    # Create figure
    fig, ax = plt.subplots(figsize=(14, 4))
    
    # Strip plot
    y_positions = [0] * len(trial_ids)
    ax.scatter(trial_ids, y_positions, c=colors, alpha=0.6, s=20)
    
    # Labels
    ax.set_title('Временная диаграмма испытаний', fontsize=14, weight='bold')
    ax.set_xlabel('Номер испытания', fontsize=12)
    ax.set_yticks([])
    ax.set_ylim(-0.5, 0.5)
    
    # Legend
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor='green', label='Успех'),
        Patch(facecolor='gray', label='Нет эффекта'),
        Patch(facecolor='red', label='Зависание'),
        Patch(facecolor='orange', label='Ошибка')
    ]
    ax.legend(handles=legend_elements, loc='upper right')
    
    plt.tight_layout()
    
    # Save
    output_path = Path(outdir) / 'timeline.png'
    plt.savefig(output_path, dpi=150)
    plt.close()
    
    print(f"📊 Временная диаграмма сохранена: {output_path}")
