#!/usr/bin/env python3
import os
import json

WALL_DIR = os.path.expanduser("~/Pictures/Wallpapers")

def get_wallpapers():
    wallpapers = []
    if not os.path.exists(WALL_DIR):
        return wallpapers
    
    for f in os.listdir(WALL_DIR):
        if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
            path = os.path.join(WALL_DIR, f)
            wallpapers.append({
                "name": f,
                "path": path
            })
    
    wallpapers.sort(key=lambda x: x["name"].lower())
    return wallpapers

if __name__ == "__main__":
    print(json.dumps(get_wallpapers()))
