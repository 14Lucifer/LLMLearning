#!/bin/bash

# Script to set up a Linux environment with Docker, Portainer, Apache Superset, and VSCode
# Ensure this script is run with sudo privileges

# This script performs the following steps:
# 1. Installs Docker and removes conflicting packages.
# 2. Sets up Portainer for Docker management.
# 3. Installs Apache Superset for data visualization.
# 4. Installs VSCode for code editing.
# 5. Ensures all containers are healthy and functional.
# 6. Restarts containers to apply changes where necessary.
# 7. Sets up a simple Python web server using systemd.

set -e

# Function to print progress messages
echo_progress() {
  echo -e "\e[1;32m[INFO]\e[0m $1"
}

# Confirm with the user before proceeding
echo " "
echo -e "\e[1;34mThis script will perform the following actions:\e[0m"
echo "1. Install Docker and remove conflicting packages."
echo "2. Set up Portainer for Docker management."
echo "3. Install Apache Superset for data visualization."
echo "4. Install VSCode for code editing."
echo "6. Restart containers to apply changes where necessary."
echo "7. Set up a simple Python web server."
echo " "
echo "Do you want to proceed? (yes/no): "
read -r user_input

if [[ "$user_input" != "yes" ]]; then
  echo_progress "Installation aborted by user."
  exit 1
fi

# Step 1: Install Docker
echo_progress "Starting Docker installation..."

# Remove conflicting packages
echo_progress "Removing conflicting Docker-related packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  apt-get remove -y "$pkg" && echo_progress "Removed $pkg"
done

# Update package list and install prerequisites
echo_progress "Installing prerequisites for Docker..."
apt-get update -y
apt-get install -y ca-certificates curl

# Add Docker's GPG key
echo_progress "Adding Docker's GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo_progress "Adding Docker repository to Apt sources..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list and install Docker components
echo_progress "Installing Docker components..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo_progress "Docker installation completed."

# Step 2: Install Portainer
echo_progress "Starting Portainer installation..."
docker volume create portainer_data

docker run -d \
  -p 8000:8000 -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:2.21.5

echo_progress "Portainer installation completed."

# Step 3: Install Apache Superset
echo_progress "Starting Apache Superset installation..."

git clone https://github.com/apache/superset
cd superset/
git checkout tags/4.1.1

docker compose -f docker-compose-image-tag.yml up -d

echo_progress "Waiting for Superset container to become healthy..."

# Wait for the superset_app container to be healthy
while :
do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' superset_app 2>/dev/null || echo "")
  if [ "$STATUS" = "healthy" ]; then
    echo_progress "Superset container is healthy."
    break
  fi
  echo_progress "Superset container is not ready yet. Retrying in 5 seconds..."
  sleep 5
done

# Run pip install inside the Superset container
echo_progress "Installing Python package inside the Superset container..."
docker exec superset_app pip install clickhouse-connect

echo_progress "Restarting containers to apply changes..."
docker restart superset_app
docker restart portainer

echo_progress "Apache Superset installation completed."

# Step 5: Install VSCode
echo_progress "Starting VSCode installation..."
curl -fsSL https://code-server.dev/install.sh | sh
systemctl enable --now code-server@$USER
systemctl start code-server@$USER
mv /$USER/.config/code-server/config.yaml /$USER/.config/code-server/config.yaml.bak
echo "bind-addr: 0.0.0.0:9080" >> /$USER/.config/code-server/config.yaml
echo "auth: password" >> /$USER/.config/code-server/config.yaml
echo "password: 8Sw31oCb67" >> /$USER/.config/code-server/config.yaml
echo "cert: false" >> /$USER/.config/code-server/config.yaml
systemctl restart code-server@$USER
echo_progress "VSCode installation completed."

# Step 6: Set up Python Web Server using systemd
echo_progress "Setting up a simple Python web server using systemd..."
cp /$USER/LLMLearning/tools/PythonWebServer/python-http.service /etc/systemd/system/
/usr/bin/pip3 install flask
systemctl start python-http
systemctl enable python-http
echo_progress "Python web server setup completed successfully."

# Final message
echo_progress "Environment setup completed successfully!"
echo_progress " "
echo_progress "Services          | Type   | Port          | Credential"
echo_progress "----------------- | ------ | ------------- | ------------------------"
echo_progress "Portainer         | Docker | 9443 (HTTPS)  | Setup at initial config"
echo_progress "Superset          | Docker | 8088 (HTTP)   | admin/admin"
echo_progress "VScode            | OS     | 9080 (HTTP)   | 8Sw31oCb67"
echo_progress "Python Web Server | OS     | 80 (HTTP)     | "
