#!/usr/bin/env python3
import os
import configparser
import json

STATS = os.path.expanduser("~/.config/quickshell/stats.txt")

def load_stats():
    counts = {}
    if not os.path.exists(STATS):
        return counts
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
    return counts

def find_icon(icon_name):
    if not icon_name:
        return ""
    if icon_name.startswith("/"):
        return icon_name if os.path.exists(icon_name) else ""

    sizes = ["256x256", "128x128", "64x64", "48x48", "scalable"]
    theme_dirs = [
        os.path.expanduser("~/.local/share/icons"),
        "/usr/share/icons",
        "/usr/share/pixmaps",
    ]
    extensions = [".png", ".svg", ".xpm"]

    for base in theme_dirs:
        if not os.path.exists(base):
            continue
        for theme in os.listdir(base):
            for size in sizes:
                for category in ["apps", "applications", ""]:
                    parts = [base, theme, size, category, icon_name] if category else [base, theme, size, icon_name]
                    path_no_ext = os.path.join(*parts)
                    for ext in extensions:
                        p = path_no_ext + ext
                        if os.path.exists(p):
                            return p

    for ext in extensions:
        p = f"/usr/share/pixmaps/{icon_name}{ext}"
        if os.path.exists(p):
            return p

    try:
        import xdg.IconTheme
        path = xdg.IconTheme.getIconPath(icon_name, 48)
        if path:
            return path
    except ImportError:
        pass

    return ""

def get_apps():
    stats = load_stats()
    apps = []
    dirs = [
        "/usr/share/applications",
        "/usr/local/share/applications",
        os.path.expanduser("~/.local/share/applications")
    ]
    seen_execs = set()

    for d in dirs:
        if not os.path.exists(d):
            continue
        for f in os.listdir(d):
            if not f.endswith(".desktop"):
                continue
            path = os.path.join(d, f)
            config = configparser.ConfigParser(interpolation=None)
            try:
                config.read(path, encoding='utf-8')
                if "Desktop Entry" not in config:
                    continue
                entry = config["Desktop Entry"]
                if entry.getboolean("NoDisplay", False):
                    continue
                name = entry.get("Name", f)
                exe = entry.get("Exec", "").split("%")[0].strip()
                icon_name = entry.get("Icon", "")
                icon_path = find_icon(icon_name)
                if not exe or exe in seen_execs:
                    continue
                apps.append({
                    "name": name,
                    "icon": icon_path,
                    "exec": exe,
                    "launches": stats.get(exe, 0)
                })
                seen_execs.add(exe)
            except Exception:
                continue

    apps.sort(key=lambda x: (-x["launches"], x["name"].lower()))
    return apps

if __name__ == "__main__":
    print(json.dumps(get_apps()))
