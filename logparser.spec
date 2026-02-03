# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec file for Log Parser desktop application.
"""

import sys
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

block_cipher = None

# Collect all webview dependencies
webview_hiddenimports = collect_submodules('webview')

a = Analysis(
    ['desktop.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('templates', 'templates'),
        ('uploads', 'uploads'),
    ],
    hiddenimports=[
        'webview',
        'flask',
        'jinja2',
        'werkzeug',
        'markupsafe',
        'click',
        'itsdangerous',
        'blinker',
    ] + webview_hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='LogParser',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,  # No console window
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

# macOS app bundle
if sys.platform == 'darwin':
    app = BUNDLE(
        exe,
        name='LogParser.app',
        icon=None,  # Add icon path here if you have one: 'icon.icns'
        bundle_identifier='com.logparser.app',
        info_plist={
            'CFBundleName': 'Log Parser',
            'CFBundleDisplayName': 'Log Parser',
            'CFBundleVersion': '1.0.0',
            'CFBundleShortVersionString': '1.0.0',
            'NSHighResolutionCapable': True,
        },
    )
