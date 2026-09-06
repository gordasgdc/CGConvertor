# build-windows.spec
# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[
        ('ffmpeg/ffmpeg.exe', '.'),
        ('ffmpeg/ffprobe.exe', '.'),
        # [2026-09-06] mpv bundle-uit direct in instalator — inainte se
        # descarca la runtime in %APPDATA%\CGConvertor\bin\mpv\, ceea ce
        # putea produce PermissionError (Roaming sincronizat de OneDrive/
        # politici de domeniu pe unele masini, sau blocaj tranzitoriu de
        # antivirus). Cu bundling, marea majoritate a userilor nu mai
        # ajung NICIODATA la acel cod - vezi dependency_manager.find_mpv(),
        # care verifica bundle-ul INTAI. Descarcat de CI (vezi
        # .github/workflows/build-windows.yml), exact acelasi tipar ca
        # ffmpeg de mai sus.
        ('mpv/mpv.exe', 'mpv'),
    ],
    # CGConvertor.ico e bundle-uit si ca DATA (nu doar ca --icon al exe-ului
    # insusi) - main.py._set_window_icon() il citeste la runtime din
    # sys._MEIPASS ca sa seteze explicit iconita FERESTREI (title bar +
    # taskbar), separat de iconita exe-ului setata mai jos.
    # [2026-09-06] Ghidul PDF, bundle-uit ca sa fie accesibil din meniul
    # Ajutor (main.py, _open_help_guide) fara sa depinda de o instalare
    # separata a arhivei installer/.
    datas=[('CGConvertor.ico', '.'), ('../installer/Instructiuni_Utilizare.pdf', '.')],
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
