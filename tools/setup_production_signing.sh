#!/usr/bin/env bash
#
# setup_production_signing.sh - NūriTalk Android Production Signing Setup Utility
#
# Guides secure generation of an Android production upload keystore and
# configures the gitignored `android/key.properties` file for release builds.
#
# Usage:
#   bash tools/setup_production_signing.sh            # Interactive setup
#   bash tools/setup_production_signing.sh --dry-run  # Pre-flight checks & simulation
#   bash tools/setup_production_signing.sh --check    # Check existing configuration
#   bash tools/setup_production_signing.sh --help     # Show help & security guidance
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANDROID_DIR="${PROJECT_ROOT}/android"
KEY_PROPERTIES="${ANDROID_DIR}/key.properties"
DEFAULT_KEYSTORE="${ANDROID_DIR}/upload-keystore.jks"
DEFAULT_ALIAS="upload"

show_help() {
  cat <<'EOF'
NūriTalk - Android Production Signing Setup Utility

USAGE:
  bash tools/setup_production_signing.sh [OPTIONS]

OPTIONS:
  --dry-run   Run pre-flight checks and validate signing configuration
              without prompting for credentials or creating any files.
  --check     Audit existing android/key.properties and keystore files,
              checking existence, permissions, and Git exclusion.
  -h, --help  Show this help message and security guidance.

SECURITY GUARANTEES:
  1. Keystore files (*.jks) and android/key.properties are gitignored.
  2. Passwords entered interactively are masked and NEVER written to logs or history.
  3. Generated files are assigned strict POSIX permissions (chmod 600).
  4. Release builds remain fail-closed: release artifacts cannot build with
     missing credentials unless explicitly bypassed for local test builds.

OFFLINE BACKUP REQUIREMENT:
  After creating the production upload keystore:
  - Copy android/upload-keystore.jks to an encrypted offline drive or secure vault.
  - Store the keystore password and key password in an organization password manager.
  - Losing this keystore prevents publishing app updates on Google Play!
EOF
}

check_prerequisites() {
  local failed=0

  # 1. Verify Git availability and repository root
  if ! command -v git &>/dev/null; then
    echo "[-] Error: 'git' command not found." >&2
    failed=1
  elif [ ! -d "${PROJECT_ROOT}/.git" ]; then
    echo "[-] Error: Project root is not a Git repository: ${PROJECT_ROOT}" >&2
    failed=1
  fi

  # 2. Verify JDK keytool availability
  local keytool_bin=""
  if command -v keytool &>/dev/null; then
    keytool_bin="$(command -v keytool)"
  elif [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/keytool" ]; then
    keytool_bin="${JAVA_HOME}/bin/keytool"
  elif [ -n "${HOME:-}" ] && [ -x "${HOME}/.jdk/jdk-21.0.12.1+1/bin/keytool" ]; then
    keytool_bin="${HOME}/.jdk/jdk-21.0.12.1+1/bin/keytool"
  fi

  if [ -z "${keytool_bin}" ]; then
    echo "[-] Error: 'keytool' utility not found. Please ensure JDK 17+ is installed." >&2
    failed=1
  fi

  # 3. Verify Git exclusion rules
  if ! (cd "${PROJECT_ROOT}" && git check-ignore -q "${KEY_PROPERTIES}" 2>/dev/null); then
    echo "[-] Error: ${KEY_PROPERTIES} is NOT ignored by Git! Check .gitignore." >&2
    failed=1
  fi

  if ! (cd "${PROJECT_ROOT}" && git check-ignore -q "${DEFAULT_KEYSTORE}" 2>/dev/null); then
    echo "[-] Error: ${DEFAULT_KEYSTORE} is NOT ignored by Git! Check .gitignore." >&2
    failed=1
  fi

  # 4. Verify build.gradle.kts signing configuration
  local gradle_file="${ANDROID_DIR}/app/build.gradle.kts"
  if [ ! -f "${gradle_file}" ]; then
    echo "[-] Error: Gradle file not found: ${gradle_file}" >&2
    failed=1
  elif ! grep -q "hasValidReleaseKey" "${gradle_file}"; then
    echo "[-] Error: build.gradle.kts missing release signing guard logic." >&2
    failed=1
  fi

  return ${failed}
}

run_check() {
  echo "================================================================================"
  echo "NūriTalk - Android Signing Configuration Audit"
  echo "================================================================================"

  echo -n "[*] Checking pre-requisites... "
  if check_prerequisites; then
    echo "OK"
  else
    echo "FAILED"
    return 1
  fi

  echo "[*] Gitignore Security Audit:"
  if (cd "${PROJECT_ROOT}" && git check-ignore "${KEY_PROPERTIES}" "${DEFAULT_KEYSTORE}"); then
    echo "    [+] android/key.properties is properly gitignored."
    echo "    [+] Keystore (*.jks) is properly gitignored."
  else
    echo "    [-] SECURITY RISK: Credentials are not properly excluded in Git!" >&2
    return 1
  fi

  echo "[*] File Existence & Permissions Audit:"
  if [ -f "${KEY_PROPERTIES}" ]; then
    local perms
    perms="$(stat -c "%a" "${KEY_PROPERTIES}" 2>/dev/null || stat -f "%Op" "${KEY_PROPERTIES}" 2>/dev/null || echo "unknown")"
    echo "    [+] ${KEY_PROPERTIES} exists (permissions: ${perms})."
  else
    echo "    [i] ${KEY_PROPERTIES} is not yet created (release builds require -PallowDebugSigningForRelease=true)."
  fi

  if [ -f "${DEFAULT_KEYSTORE}" ]; then
    local kperms
    kperms="$(stat -c "%a" "${DEFAULT_KEYSTORE}" 2>/dev/null || stat -f "%Op" "${DEFAULT_KEYSTORE}" 2>/dev/null || echo "unknown")"
    echo "    [+] Keystore file exists: ${DEFAULT_KEYSTORE} (permissions: ${kperms})."
  else
    echo "    [i] Keystore file is not yet created: ${DEFAULT_KEYSTORE}."
  fi

  echo "================================================================================"
  echo "AUDIT COMPLETE: Configuration and security guards are operational."
  echo "================================================================================"
}

run_dry_run() {
  echo "================================================================================"
  echo "NūriTalk - Production Signing Setup [DRY-RUN MODE]"
  echo "================================================================================"
  echo "[i] Running all pre-flight checks without modifying files or prompting for secrets..."

  if ! check_prerequisites; then
    echo "[-] Pre-flight checks failed. Please address the errors above." >&2
    return 1
  fi

  echo "[+] Git repository verified: ${PROJECT_ROOT}"
  echo "[+] JDK keytool detected."
  echo "[+] Git ignore rules verified (key.properties and *.jks excluded)."
  echo "[+] Android Gradle build configuration verified."
  echo ""
  echo "[i] Simulated Keystore Generation Command:"
  echo "    keytool -genkeypair -v -keystore ${DEFAULT_KEYSTORE} \\"
  echo "      -alias ${DEFAULT_ALIAS} -keyalg RSA -keysize 4096 -validity 10000 \\"
  echo "      -storetype PKCS12 -dname \"CN=NuriTalk Release, OU=Mobile, O=Kinder Horizon Foundation, C=DE\""
  echo ""
  echo "[i] Simulated android/key.properties Configuration:"
  echo "    storeFile=upload-keystore.jks"
  echo "    storePassword=[MASKED]"
  echo "    keyAlias=${DEFAULT_ALIAS}"
  echo "    keyPassword=[MASKED]"
  echo ""
  echo "[+] Dry-run succeeded: Setup script is fully validated and ready for human execution."
  echo "================================================================================"
}

run_interactive() {
  echo "================================================================================"
  echo "NūriTalk - Interactive Production Signing Setup"
  echo "================================================================================"
  echo "This tool will guide you through generating the Android production upload"
  echo "keystore and configuring android/key.properties."
  echo ""
  echo "CRITICAL SECURITY NOTICE:"
  echo "- The generated keystore is the cryptographic identity of NūriTalk."
  echo "- NEVER commit key.properties or the keystore file to Git."
  echo "- You MUST securely back up upload-keystore.jks after this process."
  echo "================================================================================"
  echo ""

  if ! check_prerequisites; then
    echo "[-] Pre-flight checks failed. Aborting." >&2
    exit 1
  fi

  # Check for existing configuration
  if [ -f "${KEY_PROPERTIES}" ] || [ -f "${DEFAULT_KEYSTORE}" ]; then
    echo "[!] WARNING: Existing signing configuration detected:"
    [ -f "${KEY_PROPERTIES}" ] && echo "    - ${KEY_PROPERTIES}"
    [ -f "${DEFAULT_KEYSTORE}" ] && echo "    - ${DEFAULT_KEYSTORE}"
    echo ""
    read -r -p "Overwrite existing signing configuration? (type 'yes' to proceed): " confirm_overwrite
    if [ "${confirm_overwrite}" != "yes" ]; then
      echo "Setup aborted by user. Existing configuration preserved."
      exit 0
    fi
  fi

  # Locate keytool
  local keytool_bin="keytool"
  if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/keytool" ]; then
    keytool_bin="${JAVA_HOME}/bin/keytool"
  fi

  # Interactive prompts
  read -r -p "Enter keystore path [default: ${DEFAULT_KEYSTORE}]: " user_keystore
  local keystore_path="${user_keystore:-${DEFAULT_KEYSTORE}}"

  read -r -p "Enter key alias [default: ${DEFAULT_ALIAS}]: " user_alias
  local key_alias="${user_alias:-${DEFAULT_ALIAS}}"

  # Passwords (masked, never echoed)
  echo ""
  echo "--- Keystore Passwords (input will not be displayed) ---"
  local store_pass=""
  local store_pass_confirm=""
  while true; do
    read -rsp "Enter Keystore Password (min 8 chars): " store_pass
    echo ""
    if [ ${#store_pass} -lt 8 ]; then
      echo "Password must be at least 8 characters. Please try again."
      continue
    fi
    read -rsp "Confirm Keystore Password: " store_pass_confirm
    echo ""
    if [ "${store_pass}" != "${store_pass_confirm}" ]; then
      echo "Passwords do not match. Please try again."
    else
      break
    fi
  done

  local key_pass=""
  local key_pass_confirm=""
  read -r -p "Use same password for key alias '${key_alias}'? [Y/n]: " same_pass
  if [[ "${same_pass}" =~ ^[Nn] ]]; then
    while true; do
      read -rsp "Enter Key Password (min 8 chars): " key_pass
      echo ""
      if [ ${#key_pass} -lt 8 ]; then
        echo "Password must be at least 8 characters. Please try again."
        continue
      fi
      read -rsp "Confirm Key Password: " key_pass_confirm
      echo ""
      if [ "${key_pass}" != "${key_pass_confirm}" ]; then
        echo "Passwords do not match. Please try again."
      else
        break
      fi
    done
  else
    key_pass="${store_pass}"
  fi

  echo ""
  echo "[*] Generating production upload keystore with RSA 4096-bit key..."
  "${keytool_bin}" -genkeypair -v \
    -keystore "${keystore_path}" \
    -alias "${key_alias}" \
    -keyalg RSA \
    -keysize 4096 \
    -validity 10000 \
    -storetype PKCS12 \
    -storepass "${store_pass}" \
    -keypass "${key_pass}" \
    -dname "CN=NuriTalk Release, OU=Mobile AAC, O=Kinder Horizon Foundation, C=DE"

  chmod 600 "${keystore_path}"
  echo "[+] Keystore created successfully with restricted permissions (chmod 600)."

  # Relative path calculation for key.properties
  local relative_keystore
  if [[ "${keystore_path}" == "${ANDROID_DIR}/"* ]]; then
    relative_keystore="${keystore_path#"${ANDROID_DIR}/"}"
  else
    relative_keystore="${keystore_path}"
  fi

  echo "[*] Writing android/key.properties..."
  cat > "${KEY_PROPERTIES}" <<EOF
# Production Signing Configuration for NūriTalk (Git-ignored)
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
storeFile=${relative_keystore}
storePassword=${store_pass}
keyAlias=${key_alias}
keyPassword=${key_pass}
EOF

  chmod 600 "${KEY_PROPERTIES}"
  echo "[+] android/key.properties written with restricted permissions (chmod 600)."

  # Safety check: Verify Git ignores newly created files
  echo "[*] Verifying Git status..."
  if (cd "${PROJECT_ROOT}" && git status --porcelain | grep -E "key\.properties|\.jks"); then
    echo "[-] CRITICAL ALERT: Key files were NOT ignored by Git! Check .gitignore immediately!" >&2
    exit 1
  else
    echo "[+] Git safety verified: Credentials are strictly ignored by version control."
  fi

  echo ""
  echo "================================================================================"
  echo "PRODUCTION SIGNING SETUP COMPLETE"
  echo "================================================================================"
  echo "Next Steps:"
  echo "  1. Back up ${keystore_path} to secure offline storage immediately."
  echo "  2. Store passwords in your organization's encrypted vault."
  echo "  3. Build production release artifact:"
  echo "     flutter build apk --release"
  echo "  4. Verify cryptographic signature:"
  echo "     python3 tools/verify_android_signing.py --apk build/app/outputs/flutter-apk/app-release.apk"
  echo "================================================================================"
}

# Main entry point
case "${1:-}" in
  --dry-run)
    run_dry_run
    ;;
  --check)
    run_check
    ;;
  -h|--help)
    show_help
    ;;
  "")
    run_interactive
    ;;
  *)
    echo "Unknown option: $1" >&2
    echo "Run 'bash tools/setup_production_signing.sh --help' for usage." >&2
    exit 1
    ;;
esac
