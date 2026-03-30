#!/usr/bin/env python3
import os
import json
import subprocess
import configparser

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

    # Try exact match in theme dirs
    for base in theme_dirs:
        if not os.path.exists(base):
            continue
        # Check standard themes first (hicolor, etc)
        potential_themes = ["hicolor", "Papirus", "Adwaita", "breeze"]
        existing_themes = os.listdir(base)
        themes_to_check = [t for t in potential_themes if t in existing_themes] + [t for t in existing_themes if t not in potential_themes]
        
        for theme in themes_to_check:
            for size in sizes:
                for category in ["apps", "applications", ""]:
                    parts = [base, theme, size, category, icon_name] if category else [base, theme, size, icon_name]
                    path_no_ext = os.path.join(*parts)
                    for ext in extensions:
                        p = path_no_ext + ext
                        if os.path.exists(p):
                            return p

    # Try pixmaps
    for ext in extensions:
        p = f"/usr/share/pixmaps/{icon_name}{ext}"
        if os.path.exists(p):
            return p

    return ""

def get_desktop_icon(app_id):
    dirs = [
        "/usr/share/applications",
        "/usr/local/share/applications",
        os.path.expanduser("~/.local/share/applications")
    ]
    # Try common app_id variants
    variants = [app_id, app_id.lower(), app_id.capitalize()]
    if "." in app_id:
        variants.append(app_id.split(".")[-1]) # com.example.App -> App
    
    for d in dirs:
        if not os.path.exists(d):
            continue
        for f in os.listdir(d):
            if f.endswith(".desktop"):
                for var in variants:
                    if var in f.lower():
                        path = os.path.join(d, f)
                        config = configparser.ConfigParser(interpolation=None)
                        try:
                            config.read(path, encoding='utf-8')
                            if "Desktop Entry" in config:
                                icon = config["Desktop Entry"].get("Icon", "")
                                if icon:
                                    return find_icon(icon)
                        except:
                            continue
    return find_icon(app_id)

def get_running_apps():
    try:
        res = subprocess.run(["niri", "msg", "-j", "windows"], capture_output=True, text=True)
        windows = json.loads(res.stdout)
    except:
        return []

    apps = []
    seen_ids = set()
    
    for win in windows:
        app_id = win.get("app_id", "unknown")
        # Deduplicate by app_id for the dock? 
        # Actually, if there are multiple windows of the same app, 
        # a dock usually shows one icon with indicators.
        # But for "Dash-to-Dock" showing "running applications", 
        # let's group by app_id but keep track of window IDs.
        
        icon = get_desktop_icon(app_id)
        
        # Check if we already have this app_id
        found = False
        for app in apps:
            if app["app_id"] == app_id:
                app["windows"].append({"id": win["id"], "title": win["title"], "focused": win["is_focused"]})
                if win["is_focused"]:
                    app["focused"] = True
                found = True
                break
        
        if not found:
            apps.append({
                "app_id": app_id,
                "icon": icon,
                "focused": win["is_focused"],
                "windows": [{"id": win["id"], "title": win["title"], "focused": win["is_focused"]}]
            })

    return apps

if __name__ == "__main__":
    print(json.dumps(get_running_apps()))
