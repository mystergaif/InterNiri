#!/usr/bin/env bash
# Скрипт для безопасного применения обоев из Quickshell
if [ -n "$1" ]; then
    swww img "$1" --transition-type grow --transition-pos center
fi
