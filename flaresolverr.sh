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

  # Basic check: Does the service file exist?
  if [[ ! -f /etc/systemd/system/flaresolverr.service ]]; then
    msg_error "No ${APP} Installation Found! Cannot force version."
    exit 1
  fi

  # --- MODIFICATION START: Direct Download ---

  local fixed_version="v3.3.21"
  local fixed_url="https://github.com/FlareSolverr/FlareSolverr/releases/download/${fixed_version}/flaresolverr_linux_x64.tar.gz"
  # Define a specific temporary path for the download
  local download_path="/tmp/flaresolverr_${fixed_version}.tar.gz"

  msg_info "Forcing installation of ${APP} version ${fixed_version}"
  msg_info "Attempting download from: ${fixed_url}"

  # Stop the service before replacing files
  if systemctl is-active -q flaresolverr; then
    msg_info "Stopping existing ${APP} service..."
    systemctl stop flaresolverr
  fi

  # Download using explicit output file (-o)
  msg_info "Downloading to ${download_path}..."
  if curl -fsSL -o "${download_path}" "${fixed_url}"; then
    msg_ok "Download successful."
  else
    local exit_code=$?
    msg_error "Download failed! curl exit code: ${exit_code}. Aborting."
    # Try to restart service if it was running before
    if ! systemctl is-active -q flaresolverr && [[ -f /etc/systemd/system/flaresolverr.service ]]; then
       systemctl start flaresolverr &>/dev/null
    fi
    # Clean up failed download
    rm -f "${download_path}"
    exit 1 # Exit script on download failure
  fi

  # Extract the archive, overwriting existing files in /opt
  msg_info "Extracting ${download_path} to /opt (overwriting)..."
  # Use --overwrite to ensure replacement of existing files
  if tar --overwrite -xzf "${download_path}" -C /opt; then
    msg_ok "Extraction complete."
  else
    msg_error "Extraction failed! Aborting."
    # Try to restart service if it was running before
    if ! systemctl is-active -q flaresolverr && [[ -f /etc/systemd/system/flaresolverr.service ]]; then
       systemctl start flaresolverr &>/dev/null
    fi
    # Clean up downloaded file
    rm -f "${download_path}"
    exit 1 # Exit script on extraction failure
  fi

  # Remove the downloaded archive
  msg_info "Cleaning up downloaded file: ${download_path}..."
  rm -f "${download_path}"
  msg_ok "Cleanup complete."

  # (Optional: Add permission fixes here if needed, e.g., chown -R user:group /opt/flaresolverr)

  # Start the service
  msg_info "Starting ${APP} service..."
  if systemctl start flaresolverr; then
    msg_ok "${APP} service started."
  else
    msg_error "Failed to start ${APP} service."
    # Even if start fails, the files are updated. Exit with error.
    exit 1
  fi

  # Update or remove the version file (optional, but good practice)
  echo "${fixed_version}" > "/opt/${APP}_version.txt" # Record the version installed
  # Alternatively: rm -f "/opt/${APP}_version.txt" # If you don't want version tracking

  msg_ok "${APP} has been forcefully set to version ${fixed_version}."

  # --- MODIFICATION END ---
  exit 0 # Indicate successful completion
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
