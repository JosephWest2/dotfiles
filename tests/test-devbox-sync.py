#!/usr/bin/env python3
"""Exercise opt-in sync with disposable GPG keys and synthetic deployment data."""
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import tomllib


REPO = Path(__file__).resolve().parent.parent


def run(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, **kwargs).stdout


with tempfile.TemporaryDirectory(prefix="chezmoi-devbox-test-") as tmp:
    root = Path(tmp)
    gnupg = root / "gnupg"
    gnupg.mkdir(mode=0o700)
    env = {**os.environ, "GNUPGHOME": str(gnupg)}
    try:
        run(["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase", "",
             "--quick-generate-key", "Devbox sync test <test@example.invalid>",
             "ed25519", "sign", "1d"], env=env)
        listing = run(["gpg", "--with-colons", "--list-keys"], env=env, text=True)
        recipient = next(line.split(":")[9] for line in listing.splitlines()
                         if line.startswith("fpr:"))
        run(["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase", "",
             "--quick-add-key", recipient, "cv25519", "encrypt", "1d"], env=env)
        source = root / "source"
        source.mkdir()
        shutil.copy(REPO / ".chezmoiignore", source / ".chezmoiignore")
        config_template = Path("dot_config/private_devbox/private_config.toml.tmpl")
        (source / config_template).parent.mkdir(parents=True)
        shutil.copy(REPO / config_template, source / config_template)
        (source / "private_dot_ssh").mkdir()
        encrypted = {
            ".config/devbox/deployment.json": "dot_config/private_devbox/encrypted_private_deployment.json.asc",
            ".ssh/devbox_ed25519": "private_dot_ssh/encrypted_private_devbox_ed25519.asc",
            ".ssh/devbox_ed25519.pub": "private_dot_ssh/encrypted_devbox_ed25519.pub.asc",
        }
        manifest = dict(schema_version=6, account="123456789012", region="us-east-2",
                        deployment="fixture", owner="test-owner", revision=1)
        payloads = {
            ".config/devbox/deployment.json": json.dumps(manifest).encode(),
            ".ssh/devbox_ed25519": b"synthetic private key\n",
            ".ssh/devbox_ed25519.pub": b"synthetic public key\n",
        }

        def encrypt(target):
            run(["gpg", "--batch", "--yes", "--armor", "--recipient", recipient,
                 "--output", str(source / encrypted[target]), "--encrypt"],
                input=payloads[target], env=env)

        for target in encrypted:
            encrypt(target)

        def client(name, profile, enabled, decrypt_env=env):
            home = root / name
            home.mkdir(exist_ok=True)
            cfg = root / (name + ".toml")
            cfg.write_text(f'encryption = "gpg"\n[gpg]\nrecipient = "{recipient}"\n'
                           f'[data]\ndevboxSync = {str(enabled).lower()}\n'
                           f'devboxOperatorProfile = "{profile}"\n')
            args = ["chezmoi", "--config", str(cfg), "--source", str(source),
                    "--destination", str(home), "--cache", str(root / (name + "-cache")),
                    "--persistent-state", str(root / (name + ".boltdb")),
                    "--override-data", json.dumps({"chezmoi": {"homeDir": str(home),
                                                 "hostname": name, "os": "linux"}})]
            run(args + ["apply", "--exclude=scripts"], env=decrypt_env)
            return home

        # Unenrolled machines must work without access to the decryption key.
        empty_keys = root / "empty-gnupg"
        empty_keys.mkdir(mode=0o700)
        disabled_env = {**os.environ, "GNUPGHOME": str(empty_keys)}
        off = client("unenrolled", "unused", False, disabled_env)
        assert not (off / ".config/devbox/config.toml").exists()
        assert not (off / ".ssh/devbox_ed25519").exists()

        for name, profile in [("desktop", "devbox-operator"), ("vm", "vm-operator")]:
            home = client(name, profile, True)
            for target, expected in payloads.items():
                assert (home / target).read_bytes() == expected
            config = tomllib.loads((home / ".config/devbox/config.toml").read_text())
            assert config["expected_account"] == manifest["account"]
            assert config["aws_profile"] == profile
            assert config["ssh_identity_file"] == str(home / ".ssh/devbox_ed25519")
            assert config["manifest"] == "deployment.json"
            for target in [".config/devbox/config.toml", ".config/devbox/deployment.json",
                           ".ssh/devbox_ed25519"]:
                assert stat.S_IMODE((home / target).stat().st_mode) == 0o600
            assert not (home / ".aws").exists()

        # A new encrypted export reaches both machines without changing local profiles.
        manifest.update(revision=2, owner="updated-owner")
        payloads[".config/devbox/deployment.json"] = json.dumps(manifest).encode()
        encrypt(".config/devbox/deployment.json")
        for name, profile in [("desktop", "devbox-operator"), ("vm", "vm-operator")]:
            home = client(name, profile, True)
            config = tomllib.loads((home / ".config/devbox/config.toml").read_text())
            assert config["owner"] == "updated-owner"
            assert config["aws_profile"] == profile
            assert (home / ".config/devbox/deployment.json").read_bytes() == payloads[".config/devbox/deployment.json"]

        # Opting out preserves existing files and no longer requires decryption.
        home = root / "vm"
        before = {p: p.read_bytes() for p in home.rglob("*") if p.is_file()}
        client("vm", "vm-operator", False, disabled_env)
        assert all(p.read_bytes() == body for p, body in before.items())
        print("ok - encrypted sync, separate home/profile values, updates, permissions and opt-out")
    finally:
        subprocess.run(["gpgconf", "--kill", "gpg-agent"], env=env, capture_output=True)
