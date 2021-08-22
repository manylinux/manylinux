import hashlib
import re
import subprocess

from pathlib import Path

import requests

from lastversion import latest
from lastversion.Version import Version


def _sha256(url):
    response = requests.get(
        url,
        allow_redirects=True,
        headers={"Accept": "application/octet-stream"},
        stream=True)
    response.raise_for_status()
    m = hashlib.sha256()
    for chunk in response.iter_content(chunk_size=65536):
        m.update(chunk)
    return m.hexdigest()


def _update_cpython():
    build_env = Path(__file__).parent / "docker" / "build_scripts" / "build_env.sh"
    lines = build_env.read_text().splitlines()
    re_ = re.compile(r'^CPYTHON_VERSIONS="(?P<versions>.*)"$')
    for i in range(len(lines)):
        match = re_.match(lines[i])
        if match is None:
            continue
        versions = match["versions"].split()
        for version in versions:
            current_version = Version(version)
            latest_version = latest("python/cpython", major=f'{current_version.major}.{current_version.minor}', pre_ok=current_version.is_prerelease)
            if latest_version > current_version:
                root = f"Python-{latest_version}"
                url = f"https://www.python.org/ftp/python/{latest_version.major}.{latest_version.minor}.{latest_version.micro}"
                _sha256(f"{url}/{root}.tgz")
                lines[i] = lines[i].replace(version, str(latest_version))
                build_env.write_text("\n".join(lines) + "\n")
                message = f"Bump CPython {current_version} → {latest_version}"
                print(message)
                subprocess.check_call(["git", "commit", "-am", message])
        break


def _update_with_root(tool):
    repo = {
        "autoconf": "autotools-mirror/autoconf",
        "automake": "autotools-mirror/automake",
        "libtool": "autotools-mirror/libtool",
        "git": "git/git",
        "swig": "swig/swig",
        "openssl": "openssl/openssl",
        "curl": "curl/curl",
    }
    build_env = Path(__file__).parent / "docker" / "build_scripts" / "build_env.sh"
    lines = build_env.read_text().splitlines()
    re_ = re.compile(f"^{tool.upper()}_ROOT={tool}-(?P<version>\\S+)$")
    for i in range(len(lines)):
        match = re_.match(lines[i])
        if match is None:
            continue
        current_version = Version(match["version"], char_fix_required=tool=="openssl")
        latest_version = latest(repo[tool])
        if latest_version > current_version:
            root = f"{tool}-{latest_version}"
            url = re.match(f"^{tool.upper()}_DOWNLOAD_URL=(?P<url>\\S+)$", lines[i + 2])["url"]
            url = url.replace(f"${{{tool.upper()}_ROOT}}", root)
            sha256 = _sha256(f"{url}/{root}.tar.gz")
            lines[i + 0] = f"{tool.upper()}_ROOT={root}"
            lines[i + 1] = f"{tool.upper()}_HASH={sha256}"
            build_env.write_text("\n".join(lines) + "\n")
            message = f"Bump {tool} {current_version} → {latest_version}"
            print(message)
            subprocess.check_call(["git", "commit", "-am", message])
        break


def _update_sqlite():
    build_env = Path(__file__).parent / "docker" / "build_scripts" / "build_env.sh"
    lines = build_env.read_text().splitlines()
    re_ = re.compile(f"^SQLITE_AUTOCONF_ROOT=sqlite-autoconf-(?P<version>\\S+)$")
    for i in range(len(lines)):
        match = re_.match(lines[i])
        if match is None:
            continue
        version_int = int(match["version"])
        major = version_int // 1000000
        version_int -= major * 1000000
        minor = version_int // 10000
        version_int -= minor * 10000
        patch = version_int // 100
        current_version = Version(f"{major}.{minor}.{patch}")
        latest_dict = latest("sqlite/sqlite", output_format="dict")
        latest_version = latest_dict["version"]
        if latest_version > current_version:
            version_int = latest_version.major * 1000000 + latest_version.minor * 10000 + latest_version.micro * 100
            root = f"sqlite-autoconf-{version_int}"
            url = f"https://www.sqlite.org/{latest_dict['tag_date'].year}"
            sha256 = _sha256(f"{url}/{root}.tar.gz")
            lines[i + 0] = f"SQLITE_AUTOCONF_ROOT={root}"
            lines[i + 1] = f"SQLITE_AUTOCONF_HASH={sha256}"
            lines[i + 2] = f"SQLITE_AUTOCONF_DOWNLOAD_URL={url}"
            build_env.write_text("\n".join(lines) + "\n")
            message = f"Bump sqlite {current_version} → {latest_version}"
            print(message)
            subprocess.check_call(["git", "commit", "-am", message])
        break


def _update_with_gh(tool):
    repo = {
        "patchelf": "NixOS/patchelf",
        "libxcrypt": "besser82/libxcrypt",
    }
    build_env = Path(__file__).parent / "docker" / "build_scripts" / "build_env.sh"
    lines = build_env.read_text().splitlines()
    re_ = re.compile(f"^{tool.upper()}_VERSION=(?P<version>\\S+)$")
    for i in range(len(lines)):
        match = re_.match(lines[i])
        if match is None:
            continue
        current_version = Version(match["version"])
        latest_tag = latest(repo[tool], output_format="tag")
        latest_version = Version(latest_tag)
        if latest_version > current_version:
            url = re.match(f"^{tool.upper()}_DOWNLOAD_URL=(?P<url>\\S+)$", lines[i + 2])["url"]
            sha256 = _sha256(f"{url}/{latest_tag}.tar.gz")
            lines[i + 0] = f"{tool.upper()}_VERSION={latest_version}"
            lines[i + 1] = f"{tool.upper()}_HASH={sha256}"
            build_env.write_text("\n".join(lines) + "\n")
            message = f"Bump {tool} {current_version} → {latest_version}"
            print(message)
            subprocess.check_call(["git", "commit", "-am", message])
        break


def main():
    _update_cpython()
    _update_sqlite()
    for tool in ["autoconf", "automake", "curl", "libtool", "git", "swig", "openssl"]:
        _update_with_root(tool)
    for tool in ["patchelf", "libxcrypt"]:
        _update_with_gh(tool)


if __name__ == "__main__":
    main()
