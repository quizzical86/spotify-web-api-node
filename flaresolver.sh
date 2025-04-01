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

# --- MODIFIED update_script FUNCTION STARTS HERE ---
function update_script() {
  header_info
  check_container_storage
  check_container_resources

  # Basic check: Does the service file exist?
  if [[ ! -f /etc/systemd/system/flaresolverr.service ]]; then
    msg_error "No ${APP} Installation Found! Cannot force version."
    exit 1
  fi

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
  if curl --fail --silent --show-error --location -o "${download_path}" "${fixed_url}"; then # Use --fail for better error detection
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
  # Ensure the target directory exists (though /opt should)
  mkdir -p /opt
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

  # (Optional: Add permission fixes here if needed based on how the service runs)
  # Example: Check if a 'flaresolverr' user exists and set ownership
  # if id -u flaresolverr >/dev/null 2>&1; then
  #   chown -R flaresolverr:flaresolverr /opt/flaresolverr
  # fi

  # Start the service
  msg_info "Starting ${APP} service..."
  if systemctl start flaresolverr; then
    msg_ok "${APP} service started."
  else
    msg_error "Failed to start ${APP} service."
    # Even if start fails, the files are updated. Exit with error.
    exit 1
  fi

  # Record the installed version (useful for future reference, even if not checked)
  echo "${fixed_version}" > "/opt/${APP}_version.txt"

  msg_ok "${APP} has been forcefully set to version ${fixed_version}."

  exit 0 # Indicate successful completion
}
# --- MODIFIED update_script FUNCTION ENDS HERE ---

start # This calls check_update -> update_script if the container exists
build_container # This handles the initial creation/setup
description

# --- NOTE ---
# The initial installation of FlareSolverr is handled by the 'build_container' function,
# which likely uses mechanisms from the sourced 'build.func'.
# That process is NOT modified by the changes above in 'update_script'.
# If the initial installation also needs to be fixed to version v3.3.21,
# adjustments might be needed *after* the 'build_container' or 'description' lines,
# or by modifying how 'build.func' is used if possible.
# The change above only affects the logic when this script is run *again* on an
# existing container (triggering update_script).

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}"
