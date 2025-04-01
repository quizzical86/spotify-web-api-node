#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster) | Co-Author: remz1337
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/FlareSolverr/FlareSolverr

APP="FlareSolverr"
var_tags="proxy"
var_cpu="2"
var_ram="2048"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  # Check if the service file exists as a basic check for prior installation attempt
  if [[ ! -f /etc/systemd/system/flaresolverr.service ]]; then
    msg_error "No ${APP} Installation Found! Cannot force version."
    exit 1 # Use non-zero exit code for error
  fi

  # --- MODIFICATION START ---
  # Define the fixed URL and filename directly
  FIXED_VERSION="v3.3.21"
  FIXED_URL="https://github.com/FlareSolverr/FlareSolverr/releases/download/${FIXED_VERSION}/flaresolverr_linux_x64.tar.gz"
  FIXED_FILENAME="flaresolverr_linux_x64.tar.gz" # Define filename for clarity

  # Always download and install the specific version v3.3.21
  # No version checks performed.
  msg_info "Setting ${APP} to version ${FIXED_VERSION}..."

  # Stop the service if it's running
  if systemctl is-active -q flaresolverr; then
    msg_info "Stopping existing ${APP} service..."
    systemctl stop flaresolverr
  fi

  # Download the specific fixed version
  msg_info "Downloading ${FIXED_URL}..."
  if curl -fsSL "${FIXED_URL}" -o "${FIXED_FILENAME}"; then
      msg_ok "Download complete."
  else
      msg_error "Download failed! Aborting."
      # Attempt to start the service again if it was stopped previously
      if ! systemctl is-active -q flaresolverr; then systemctl start flaresolverr &>/dev/null; fi
      exit 1
  fi

  # Extract the archive, overwriting existing files
  msg_info "Extracting ${FIXED_FILENAME} to /opt (overwriting)..."
  # Use --overwrite to handle existing files from previous versions
  if tar --overwrite -xzf "${FIXED_FILENAME}" -C /opt; then
      msg_ok "Extraction complete."
  else
      msg_error "Extraction failed! Aborting."
      rm -f "${FIXED_FILENAME}" # Clean up downloaded file on failure
      # Attempt to start the service again if it was stopped previously
      if ! systemctl is-active -q flaresolverr; then systemctl start flaresolverr &>/dev/null; fi
      exit 1
  fi

  # Remove the downloaded archive
  msg_info "Cleaning up ${FIXED_FILENAME}..."
  rm -f "${FIXED_FILENAME}" # Use -f to avoid error if file somehow doesn't exist
  msg_ok "Cleanup complete."

  # Ensure correct permissions (adjust if needed based on original script's behavior)
  # chown -R flaresolverr:flaresolverr /opt/flaresolverr # Example: Uncomment/adjust if a specific user is needed

  # Start the service
  msg_info "Starting ${APP} service..."
  if systemctl start flaresolverr; then
      msg_ok "${APP} service started."
  else
      msg_error "Failed to start ${APP} service."
      # Even if start fails, the files are updated. Exit with error.
      exit 1
  fi

  msg_ok "${APP} has been set to version ${FIXED_VERSION}."

  # Remove the version tracking file if it exists, as it's no longer relevant
  rm -f /opt/${APP}_version.txt

  # --- MODIFICATION END ---
  exit 0 # Indicate successful execution
}

start
build_container
description

# --- NOTE ---
# The changes above ONLY affect the 'update_script' function.
# The initial installation via 'build_container' might install a different version.
# This script will now forcefully install v3.3.21 when run again on the container.

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}"
