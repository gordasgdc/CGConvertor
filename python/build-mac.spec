# build-mac.spec
# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[
        ('ffmpeg/ffmpeg', '.'),
        ('ffmpeg/ffprobe', '.'),
    ],
    datas=[],
    hiddenimports=['tkinterdnd2'],
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
    name='CGConvertor Standalone',
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
    icon='CGConvertor.icns'
)

app = BUNDLE(
    exe,
    name='CGConvertor Standalone.app',
    icon='CGConvertor.icns',
    bundle_identifier='com.gordasgdc.CGConvertor.standalone',
    info_plist={
        'CFBundleShortVersionString': '1.0.0',
        'CFBundleVersion': '1.0.0',
        'NSHumanReadableCopyright': 'Copyright (c) 2026 Cristi Gordas',
        'NSHighResolutionCapable': True,
    }
)
