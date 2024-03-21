import os
import re
from pathlib import Path

import nox


@nox.session
def update_python_dependencies(session):
    if getattr(session.virtualenv, "venv_backend", "") != "uv":
        session.install("uv>=0.1.23")

    env = os.environ.copy()
    # CUSTOM_COMPILE_COMMAND is a pip-compile option that tells users how to
    # regenerate the constraints files
    env["UV_CUSTOM_COMPILE_COMMAND"] = f"nox -s {session.name}"

    for python_minor in range(7, 14):
        python_version = f"3.{python_minor}"
        session.run(
            "uv", "pip", "compile",
            f"--python-version={python_version}",
            "--generate-hashes",
            "requirements.in",
            "--upgrade",
            "--output-file",
            f"docker/build_scripts/requirements{python_version}.txt",
            env=env,
        )

    # tools
    python_version = "3.10"
    session.run(
        "uv", "pip", "compile",
        f"--python-version={python_version}",
        "--generate-hashes",
        "requirements-base-tools.in",
        "--upgrade",
        "--output-file",
        "docker/build_scripts/requirements-base-tools.txt",
        env=env,
    )
    tools = Path("requirements-tools.in").read_text().split("\n")
    for tool in tools:
        if tool.strip() == "":
            continue
        tmp_file = Path(session.create_tmp()) / f"{tool}.in"
        tmp_file.write_text(f"{tool}\n")
        session.run(
            "uv", "pip", "compile",
            f"--python-version={python_version}",
            "--generate-hashes",
            str(tmp_file),
            "--upgrade",
            "--output-file",
            f"docker/build_scripts/requirements-tools/{tool}",
            env=env,
        )


@nox.session(python="3.11", reuse_venv=True)
def update_native_dependencies(session):
    session.install("lastversion>=3.5.0", "packaging", "requests")
    session.run("python", "tools/update_native_dependencies.py", *session.posargs)


@nox.session(python="3.11", reuse_venv=True)
def update_interpreters_download(session):
    session.install("packaging", "requests")
    session.run("python", "tools/update_interpreters_download.py", *session.posargs)
