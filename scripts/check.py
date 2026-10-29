#!/usr/bin/env python3
"""Run the Lonn plugin integration checks in an isolated Linux/Xvfb session."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from zipfile import ZipFile

project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--celeste", type=Path, default=Path(os.environ.get("CELESTE",
    str(Path.home()/".local/share/Steam/steamapps/common/Celeste"))))
parser.add_argument("--loenn-archive", type=Path,
    default=Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home()/".config")))/"Olympus/loenn/Lönn.love")
parser.add_argument("--launcher", default=shutil.which("loenn") or str(Path.home()/".local/bin/loenn"))
args = parser.parse_args()
xvfb = shutil.which("Xvfb")
if not xvfb:
    parser.error("Xvfb is required")
if not args.loenn_archive.is_file() or not (args.celeste/"Content").is_dir():
    parser.error("Provide the installed Lonn .love archive and Celeste directory")
executable = next((args.celeste/name for name in ("Celeste.dll", "Celeste.exe")
    if (args.celeste/name).is_file()), None)
if executable is None:
    parser.error("Cannot find Celeste.dll or Celeste.exe")

root = Path(tempfile.mkdtemp(prefix="loenn-visual-previews-check-"))
app, game, storage = root/"app", root/"game", root/"storage"
app.mkdir(); game.mkdir(); storage.mkdir()
with ZipFile(args.loenn_archive) as archive:
    archive.extractall(app)
with (app/"main.lua").open("a") as f:
    f.write("\n" + (project/"tests/integration.lua").read_text())
(game/"Content").symlink_to((args.celeste/"Content").resolve(), target_is_directory=True)
(game/executable.name).symlink_to(executable.resolve())
(game/"Mods").mkdir()
(game/"Mods/LoennVisualPreviews").symlink_to(project, target_is_directory=True)
(storage/"settings.conf").write_text('{celesteGameDirectory = "' + game.as_posix() +
    '", ui = {theme = {defaultFontSize = 24}}, updater = {checkOnStartup = false}, backups = {enabled = false}}')
(storage/"persistence.conf").write_text("{windowWidth = 2400, windowHeight = 1500}")
path = storage/"Plugins/LoennVisualPreviews"
path.mkdir(parents=True)
(path/"settings.conf").write_text("{enabled = false, decalHoverPreviews = true}")

read_fd, write_fd = os.pipe()
with (root/"xvfb.log").open("w") as server_log:
    server = subprocess.Popen([xvfb, "-displayfd", str(write_fd), "-screen", "0", "2400x1500x24",
        "-nolisten", "tcp"], pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=server_log)
os.close(write_fd)
try:
    with os.fdopen(read_fd) as f:
        display = f.readline().strip()
    if not display:
        raise RuntimeError(f"Xvfb failed; see {root/'xvfb.log'}")
    env = os.environ.copy()
    env.update(DISPLAY=":"+display, SDL_VIDEODRIVER="x11", LIBGL_ALWAYS_SOFTWARE="1",
        LOENN_CHECK_DIR=str(root), LOENN_LOVE_PATH=str(app))
    env.pop("XAUTHORITY", None)
    with (root/"test.log").open("w") as log:
        result = subprocess.run([args.launcher, "--storage-directory", str(storage)],
            env=env, stdout=log, stderr=subprocess.STDOUT, timeout=140)
    print((root/"test.log").read_text())
    print(f"Logs, coverage and screenshots: {root}")
    raise SystemExit(result.returncode)
finally:
    server.terminate()
    server.wait(timeout=5)
