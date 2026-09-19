#!/usr/bin/env python3
"""
Assemble the luci-app-nbtverify OpenWrt .ipk (new tar.gz container format,
as produced by the OpenWrt/ImmortalWrt build system since 23.05).

Layout:
  outer: gzipped tar containing ./debian-binary, ./data.tar.gz, ./control.tar.gz
  data.tar.gz:    ./ prefixed file tree of files/
  control.tar.gz: ./control (metadata), ./conffiles, ./postinst, ./prerm

Run:  python3 tools/build_ipk.py
Output: bin/luci-app-nbtverify_<version>_<arch>.ipk
"""

import gzip
import io
import os
import sys
import tarfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES_DIR = os.path.join(ROOT, "files")
CONTROL_DIR = os.path.join(ROOT, "control")
OUT_DIR = os.path.join(ROOT, "bin")

PKG = "luci-app-nbtverify"
VERSION = "1.0.8-1"
ARCH = "aarch64_cortex-a53"
SOURCE_DATE_EPOCH = 1789449600  # 2026-09-15 16:00:00 UTC, fixed for reproducibility

EXEC_PATHS = {
    "usr/bin/nbtverify",
    "etc/init.d/nbtverify",
    "postinst",
    "prerm",
}


def pkg_size_kb():
    total = 0
    for dirpath, _dirnames, filenames in os.walk(FILES_DIR):
        for fn in filenames:
            total += os.path.getsize(os.path.join(dirpath, fn))
    return (total + 1023) // 1024


def make_tarfile(members, gzip_out=True):
    """members: list of (arcname, fileobj_or_bytes, mode, is_dir)."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w") as tar:
        for arcname, data, mode, is_dir in members:
            info = tarfile.TarInfo(arcname)
            info.mtime = SOURCE_DATE_EPOCH
            info.mode = mode
            info.uid = 0
            info.gid = 0
            info.uname = "root"
            info.gname = "root"
            if is_dir:
                info.type = tarfile.DIRTYPE
                info.size = 0
                tar.addfile(info)
            else:
                if isinstance(data, str):
                    data = data.encode("utf-8")
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
    raw = buf.getvalue()
    if gzip_out:
        return gzip.compress(raw, mtime=SOURCE_DATE_EPOCH)
    return raw


def collect_data_members():
    members = []
    members.append(("./", b"", 0o755, True))
    for dirpath, dirnames, filenames in os.walk(FILES_DIR):
        dirnames.sort()
        rel = os.path.relpath(dirpath, FILES_DIR)
        for d in sorted(dirnames):
            arc = "./" + (os.path.join(rel, d) if rel != "." else d).replace("\\", "/") + "/"
            members.append((arc, b"", 0o755, True))
        for fn in sorted(filenames):
            full = os.path.join(dirpath, fn)
            relfile = os.path.join(rel, fn) if rel != "." else fn
            arc = "./" + relfile.replace("\\", "/")
            with open(full, "rb") as f:
                data = f.read()
            mode = 0o755 if relfile.replace("\\", "/") in EXEC_PATHS else 0o644
            members.append((arc, data, mode, False))
    return members


def collect_control_members():
    size_kb = pkg_size_kb()
    ctl = open(os.path.join(CONTROL_DIR, "control"), "r", encoding="utf-8").read()
    ctl = ctl.replace("__INSTALLED_SIZE__", str(size_kb))
    ctl = ctl.replace("__SOURCE_DATE_EPOCH__", str(SOURCE_DATE_EPOCH))
    members = [
        ("./", b"", 0o755, True),
        ("./control", ctl, 0o644, False),
    ]
    for name in ("conffiles", "postinst", "prerm"):
        path = os.path.join(CONTROL_DIR, name)
        if os.path.exists(path):
            mode = 0o755 if name in ("postinst", "prerm") else 0o644
            members.append(("./" + name, open(path, "rb").read(), mode, False))
    return members


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    data_tar = make_tarfile(collect_data_members())
    control_tar = make_tarfile(collect_control_members())

    outer_members = [
        ("./debian-binary", b"2.0\n", 0o644, False),
        ("./data.tar.gz", data_tar, 0o644, False),
        ("./control.tar.gz", control_tar, 0o644, False),
    ]
    outer = make_tarfile(outer_members)

    out_path = os.path.join(OUT_DIR, "%s_%s_%s.ipk" % (PKG, VERSION, ARCH))
    with open(out_path, "wb") as f:
        f.write(outer)
    print("Wrote %s (%d bytes)" % (out_path, len(outer)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
