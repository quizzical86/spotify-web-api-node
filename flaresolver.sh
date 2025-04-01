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

# --- MODIFIED update_script FUNCTION (for subsequent runs) ---
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
  local download_path="/tmp/flaresolverr_${fixed_version}.tar.gz" # Use /tmp

  msg_info "[Update Script] Forcing installation of ${APP} version ${fixed_version}"
  msg_info "[Update Script] Attempting download from: ${fixed_url}"

  # Stop the service before replacing files
  if systemctl is-active -q flaresolverr; then
    msg_info "[Update Script] Stopping existing ${APP} service..."
    systemctl stop flaresolverr
  fi

  # Download using explicit output file (-o)
  msg_info "[Update Script] Downloading to ${download_path}..."
  if curl --fail --silent --show-error --location -o "${download_path}" "${fixed_url}"; then
    msg_ok "[Update Script] Download successful."
  else
    local exit_code=$?
    msg_error "[Update Script] Download failed! curl exit code: ${exit_code}. Aborting."
    if ! systemctl is-active -q flaresolverr && [[ -f /etc/systemd/system/flaresolverr.service ]]; then systemctl start flaresolverr &>/dev/null; fi
    rm -f "${download_path}"
    exit 1
  fi

  # Extract the archive, overwriting existing files in /opt
  msg_info "[Update Script] Extracting ${download_path} to /opt (overwriting)..."
  mkdir -p /opt # Ensure /opt exists
  if tar --overwrite -xzf "${download_path}" -C /opt; then
    msg_ok "[Update Script] Extraction complete."
  else
    msg_error "[Update Script] Extraction failed! Aborting."
    if ! systemctl is-active -q flaresolverr && [[ -f /etc/systemd/system/flaresolverr.service ]]; then systemctl start flaresolverr &>/dev/null; fi
    rm -f "${download_path}"
    exit 1
  fi

  # Remove the downloaded archive
  msg_info "[Update Script] Cleaning up downloaded file: ${download_path}..."
  rm -f "${download_path}"
  msg_ok "[Update Script] Cleanup complete."

  # (Optional: Add permission fixes here if needed)

  # Start the service
  msg_info "[Update Script] Starting ${APP} service..."
  if systemctl start flaresolverr; then
    msg_ok "[Update Script] ${APP} service started."
  else
    msg_error "[Update Script] Failed to start ${APP} service."
    exit 1
  fi

  echo "${fixed_version}" > "/opt/${APP}_version.txt"
  msg_ok "[Update Script] ${APP} has been forcefully set to version ${fixed_version}."
  exit 0
}
# --- update_script FUNCTION ENDS HERE ---

start # This calls check_update -> update_script if the container exists
build_container # This handles the initial creation/setup (MAY USE $RELEASE and fail/install wrong version)
description # Sets container description

# --- FORCE VERSION INSTALLATION (Runs during INITIAL setup) ---
msg_info "Ensuring FlareSolverr v3.3.21 is installed..."

local fixed_version="v3.3.21"
local fixed_url="https://github.com/FlareSolverr/FlareSolverr/releases/download/${fixed_version}/flaresolverr_linux_x64.tar.gz"
local download_path="/tmp/flaresolverr_${fixed_version}_initial.tar.gz" # Use distinct name for clarity

# Stop service if build_container started it
if systemctl list-units --full -all | grep -q 'flaresolverr.service'; then
  if systemctl is-active -q flaresolverr; then
    msg_info "[Initial Setup] Stopping potentially running ${APP} service..."
    systemctl stop flaresolverr
  fi
fi

# Download v3.3.21 explicitly
msg_info "[Initial Setup] Downloading ${fixed_url} to ${download_path}..."
if curl --fail --silent --show-error --location -o "${download_path}" "${fixed_url}"; then
  msg_ok "[Initial Setup] Download successful."
else
  local exit_code=$?
  msg_error "[Initial Setup] Download failed! curl exit code: ${exit_code}. Aborting setup."
  exit 1 # Critical failure during initial setup
fi

# Extract v3.3.21, overwriting anything from build_container
msg_info "[Initial Setup] Extracting ${download_path} to /opt (overwriting)..."
mkdir -p /opt # Ensure /opt exists
if tar --overwrite -xzf "${download_path}" -C /opt; then
  msg_ok "[Initial Setup] Extraction complete."
else
  msg_error "[Initial Setup] Extraction failed! Aborting setup."
  rm -f "${download_path}"
  exit 1 # Critical failure during initial setup
fi

# Clean up download
msg_info "[Initial Setup] Cleaning up ${download_path}..."
rm -f "${download_path}"
msg_ok "[Initial Setup] Cleanup complete."

# (Optional: Add permission fixes here if needed)

# Ensure the service file exists (it should have been created by build_container or its functions)
if [[ ! -f /etc/systemd/system/flaresolverr.service ]]; then
    # If the service file is MISSING, the initial build likely failed badly.
    # We might try to recreate a basic one, but it's complex. Error out for now.
    msg_error "[Initial Setup] FlareSolverr service file not found after build! Cannot start service."
    # Attempt to create a basic service file if needed (example, might need adjustment)
    # cat <<EOF > /etc/systemd/system/flaresolverr.service
    # [Unit]
    # Description=FlareSolverr
    # After=network-online.target
    # [Service]
    # WorkingDirectory=/opt/flaresolverr
    # ExecStart=/opt/flaresolverr/flaresolverr
    # Restart=always
    # RestartSec=5
    # [Install]
    # WantedBy=multi-user.target
    # EOF
    # systemctl daemon-reload
    exit 1
fi

# Start the service with the correct files
msg_info "[Initial Setup] Starting ${APP} service with version ${fixed_version}..."
if systemctl start flaresolverr; then
  msg_ok "[Initial Setup] ${APP} service started."
else
  msg_error "[Initial Setup] Failed to start ${APP} service. Check logs: journalctl -u flaresolverr"
  # Don't exit here, setup might be "complete" but service failed. User needs URL info.
fi

# Record the installed version
echo "${fixed_version}" > "/opt/${APP}_version.txt"
msg_ok "[Initial Setup] FlareSolverr setup forced to version ${fixed_version}."
# --- END OF FORCED VERSION INSTALLATION ---


msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}"
