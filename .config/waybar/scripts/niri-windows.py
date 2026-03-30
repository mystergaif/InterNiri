#!/usr/bin/env python3
import json
import subprocess
import os

def get_niri_windows():
    try:
        # Get windows info from niri
        output = subprocess.check_output(["niri", "msg", "-j", "windows"], stderr=subprocess.DEVNULL)
        windows = json.loads(output)
        
        # Get workspaces info
        output_ws = subprocess.check_output(["niri", "msg", "-j", "workspaces"], stderr=subprocess.DEVNULL)
        workspaces = json.loads(output_ws)
        
        # Identify active workspace
        focused_ws_id = next((ws["id"] for ws in workspaces if ws["is_focused"]), None)
        
        if focused_ws_id is None:
            return ""
            
        # Count windows in focused workspace
        win_count = sum(1 for win in windows if win["workspace_id"] == focused_ws_id)
        
        # Find index of focused window in its workspace
        focused_win = next((win for win in windows if win["is_focused"]), None)
        if focused_win:
            # Sort windows by their position (simplified)
            ws_windows = [win for win in windows if win["workspace_id"] == focused_ws_id]
            # Niri doesn't provide a clear order in the list, but let's assume they are ordered or just show total
            return f"{win_count}"
        
        return str(win_count)
    except Exception:
        return ""

if __name__ == "__main__":
    count = get_niri_windows()
    if count:
        print(json.dumps({"text": f"󰖲 {count}", "tooltip": f"Windows in workspace: {count}"}))
    else:
        print(json.dumps({"text": ""}))
