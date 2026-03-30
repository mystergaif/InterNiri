#!/usr/bin/env python3
# record_launch.py — записывает запуск в ~/.config/quickshell/stats.txt
# Формат файла: одна строка = "число exec_команда"
import sys
import os

STATS = os.path.expanduser("~/.config/quickshell/stats.txt")

def record(exec_cmd):
    counts = {}
    # Читаем существующие данные
    if os.path.exists(STATS):
        with open(STATS, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                parts = line.split(" ", 1)
                if len(parts) == 2:
                    try:
                        counts[parts[1]] = int(parts[0])
                    except ValueError:
                        pass
    # Инкрементируем
    counts[exec_cmd] = counts.get(exec_cmd, 0) + 1
    # Записываем обратно
    with open(STATS, "w") as f:
        for cmd, n in counts.items():
            f.write(f"{n} {cmd}\n")

if __name__ == "__main__":
    if len(sys.argv) >= 2:
        record(sys.argv[1])
