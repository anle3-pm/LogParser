"""
Desktop wrapper for Log Parser application.
Uses pywebview to create a native window.
"""

import webview
import threading
import sys
import os

# Add the app directory to path for imports
if getattr(sys, 'frozen', False):
    # Running as compiled executable
    app_dir = sys._MEIPASS
    os.chdir(os.path.dirname(sys.executable))
else:
    # Running as script
    app_dir = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, app_dir)

from app import app

def start_server():
    """Start Flask server in a separate thread."""
    app.run(host='127.0.0.1', port=5000, debug=False, use_reloader=False)

if __name__ == '__main__':
    # Start Flask server in background thread
    server_thread = threading.Thread(target=start_server, daemon=True)
    server_thread.start()
    
    # Create native window
    window = webview.create_window(
        'Log Parser',
        'http://127.0.0.1:5000',
        width=1400,
        height=900,
        min_size=(800, 600),
        resizable=True,
        text_select=True
    )
    
    # Start the GUI (this blocks until window is closed)
    webview.start()
