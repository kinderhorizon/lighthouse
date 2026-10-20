#!/usr/bin/env python3
"""
Android Release Signing Verification Tool for NūriTalk / ACC2.

This tool audits compiled APK and AAB binaries to explicitly verify their
signing identities, ensuring debug-signed artifacts are never accidentally
classified as Google Play production-ready.

Usage:
    python3 tools/verify_android_signing.py [--all] [--apk <path>] [--aab <path>]
"""

import argparse
import os
import re
import shutil
import subprocess
import sys

DEFAULT_DEBUG_APK = "build/app/outputs/flutter-apk/app-debug.apk"
DEFAULT_RELEASE_APK = "build/app/outputs/flutter-apk/app-release.apk"
DEFAULT_RELEASE_AAB = "build/app/outputs/bundle/release/app-release.aab"

KNOWN_DEBUG_SHA256 = "A8:D0:FD:26:21:04:2A:D3:6E:94:B6:72:33:9D:7F:DD:F2:64:E3:C0:A5:28:DB:78:3A:86:CB:26:C9:88:D4:7E"


def find_apksigner():
    """Finds apksigner binary from Android SDK or PATH."""
    candidate_sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not candidate_sdk:
        home = os.environ.get("HOME")
        if home and os.path.isdir(os.path.join(home, "android-sdk")):
            candidate_sdk = os.path.join(home, "android-sdk")
    if candidate_sdk:
        build_tools_dir = os.path.join(candidate_sdk, "build-tools")
        if os.path.isdir(build_tools_dir):
            versions = sorted(os.listdir(build_tools_dir), reverse=True)
            for v in versions:
                candidate = os.path.join(build_tools_dir, v, "apksigner")
                if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                    return candidate
    return shutil.which("apksigner") or "apksigner"


def find_keytool():
    """Finds keytool from JDK or PATH."""
    jdk_dir = os.environ.get("JAVA_HOME")
    if not jdk_dir:
        home = os.environ.get("HOME")
        if home:
            fallback = os.path.join(home, ".jdk", "jdk-21.0.12.1+1")
            if os.path.isdir(fallback):
                jdk_dir = fallback
    if jdk_dir:
        candidate = os.path.join(jdk_dir, "bin", "keytool")
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return shutil.which("keytool") or "keytool"


def inspect_apk(apk_path, apksigner_cmd):
    """Inspects an APK file using apksigner."""
    if not os.path.isfile(apk_path):
        return {
            "path": apk_path,
            "exists": False,
            "error": "File does not exist",
        }

    try:
        cmd = [apksigner_cmd, "verify", "--verbose", "--print-certs", apk_path]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
        output = res.stdout + "\n" + res.stderr

        dn_match = re.search(r"Signer #1 certificate DN:\s*(.*)", output)
        sha256_match = re.search(r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F:]+)", output)
        sha1_match = re.search(r"Signer #1 certificate SHA-1 digest:\s*([0-9a-fA-F:]+)", output)
        v1_match = re.search(r"Verified using v1 scheme.*?:\s*(true|false)", output, re.IGNORECASE)
        v2_match = re.search(r"Verified using v2 scheme.*?:\s*(true|false)", output, re.IGNORECASE)
        v3_match = re.search(r"Verified using v3 scheme.*?:\s*(true|false)", output, re.IGNORECASE)

        dn = dn_match.group(1).strip() if dn_match else "UNKNOWN"
        sha256 = sha256_match.group(1).strip().upper() if sha256_match else "UNKNOWN"
        sha1 = sha1_match.group(1).strip().upper() if sha1_match else "UNKNOWN"

        is_debug = "CN=Android Debug" in dn or sha256.replace(":", "") == KNOWN_DEBUG_SHA256.replace(":", "")

        classification = "DEBUG_SIGNED_TEST_ARTIFACT" if is_debug else "PRODUCTION_SIGNED_RELEASE_ARTIFACT"

        return {
            "path": apk_path,
            "exists": True,
            "type": "APK",
            "dn": dn,
            "sha256": sha256,
            "sha1": sha1,
            "is_debug": is_debug,
            "classification": classification,
            "v1": v1_match.group(1) if v1_match else "unknown",
            "v2": v2_match.group(1) if v2_match else "unknown",
            "v3": v3_match.group(1) if v3_match else "unknown",
        }
    except Exception as e:
        return {
            "path": apk_path,
            "exists": True,
            "error": str(e),
        }


def inspect_aab(aab_path, keytool_cmd):
    """Inspects an AAB file using keytool."""
    if not os.path.isfile(aab_path):
        return {
            "path": aab_path,
            "exists": False,
            "error": "File does not exist",
        }

    try:
        cmd = [keytool_cmd, "-printcert", "-jarfile", aab_path]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
        output = res.stdout + "\n" + res.stderr

        owner_match = re.search(r"Owner:\s*(.*)", output)
        sha256_match = re.search(r"SHA256:\s*([0-9a-fA-F:]+)", output)
        sha1_match = re.search(r"SHA1:\s*([0-9a-fA-F:]+)", output)

        owner = owner_match.group(1).strip() if owner_match else "UNKNOWN"
        sha256 = sha256_match.group(1).strip().upper() if sha256_match else "UNKNOWN"
        sha1 = sha1_match.group(1).strip().upper() if sha1_match else "UNKNOWN"

        is_debug = "CN=Android Debug" in owner or sha256.replace(":", "") == KNOWN_DEBUG_SHA256.replace(":", "")
        classification = "DEBUG_SIGNED_TEST_ARTIFACT" if is_debug else "PRODUCTION_SIGNED_UPLOAD_BUNDLE"

        return {
            "path": aab_path,
            "exists": True,
            "type": "AAB",
            "dn": owner,
            "sha256": sha256,
            "sha1": sha1,
            "is_debug": is_debug,
            "classification": classification,
        }
    except Exception as e:
        return {
            "path": aab_path,
            "exists": True,
            "error": str(e),
        }


def print_report(results):
    """Prints a structured signing audit table."""
    print("=" * 80)
    print("NŪRITALK / ACC2 — ANDROID RELEASE SIGNING AUDIT REPORT")
    print("=" * 80)

    any_debug_release = False
    has_errors = False

    for item in results:
        print(f"\nTarget Artifact: {item['path']}")
        if not item.get("exists", False):
            print(f"  Status: NOT FOUND ({item.get('error', 'Missing')})")
            continue

        if "error" in item:
            print(f"  Status: ERROR ({item['error']})")
            has_errors = True
            continue

        print(f"  Artifact Type:   {item.get('type')}")
        print(f"  Certificate DN:  {item.get('dn')}")
        print(f"  SHA-256 Digest:  {item.get('sha256')}")
        print(f"  SHA-1 Digest:    {item.get('sha1')}")

        if "v2" in item:
            print(f"  Signing Schemes: v1={item.get('v1')}, v2={item.get('v2')}, v3={item.get('v3')}")

        classification = item.get("classification")
        print(f"  Classification:  {classification}")

        is_release_target = "release" in item["path"].lower()

        if item.get("is_debug"):
            if is_release_target:
                print("  SECURITY STATUS: [BLOCKED / UNSAFE FOR PRODUCTION]")
                print("                   This artifact is signed with the default Android debug key.")
                print("                   DO NOT upload to Google Play Store.")
                any_debug_release = True
            else:
                print("  SECURITY STATUS: [EXPECTED FOR DEBUG TESTING]")
        else:
            print("  SECURITY STATUS: [PRODUCTION-READY / VALID SIGNATURE]")

    print("\n" + "=" * 80)
    print("FINAL RELEASE SIGNING VERDICT:")
    if has_errors:
        print("RESULT: FAILED — Verification encountered errors.")
        return 1
    elif any_debug_release:
        print("RESULT: BLOCKED FOR GOOGLE PLAY — Release artifact(s) are signed with DEBUG key.")
        print("ACTION: Supply production keystore via android/key.properties and recompile.")
        return 2
    else:
        print("RESULT: VERIFIED — All release artifacts are signed with valid production key.")
        return 0


def main():
    parser = argparse.ArgumentParser(description="Verify Android release signing.")
    parser.add_argument("--all", action="store_true", help="Audit default debug APK, release APK, and release AAB")
    parser.add_argument("--apk", help="Specific APK path to verify")
    parser.add_argument("--aab", help="Specific AAB path to verify")
    args = parser.parse_args()

    apksigner_cmd = find_apksigner()
    keytool_cmd = find_keytool()

    targets = []
    if args.apk:
        targets.append(("apk", args.apk))
    if args.aab:
        targets.append(("aab", args.aab))

    if not targets or args.all:
        targets = [
            ("apk", DEFAULT_DEBUG_APK),
            ("apk", DEFAULT_RELEASE_APK),
            ("aab", DEFAULT_RELEASE_AAB),
        ]

    results = []
    for kind, path in targets:
        if kind == "apk":
            results.append(inspect_apk(path, apksigner_cmd))
        else:
            results.append(inspect_aab(path, keytool_cmd))

    exit_code = print_report(results)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
