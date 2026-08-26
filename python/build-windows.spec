# build-windows.spec
# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[
        ('ffmpeg/ffmpeg.exe', '.'),
        ('ffmpeg/ffprobe.exe', '.'),
    ],
    # CGConvertor.ico e bundle-uit si ca DATA (nu doar ca --icon al exe-ului
    # insusi) - main.py._set_window_icon() il citeste la runtime din
    # sys._MEIPASS ca sa seteze explicit iconita FERESTREI (title bar +
    # taskbar), separat de iconita exe-ului setata mai jos.
    datas=[('CGConvertor.ico', '.')],
    hiddenimports=['tkinterdnd2', 'cryptography.hazmat.bindings._rust'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='CGConvertor',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='CGConvertor.ico'
)
