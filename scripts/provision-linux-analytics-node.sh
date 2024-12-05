#!/usr/bin/env bash
if [[ -n "$LIBRA_SCRIPT_DEBUG" ]]; then
    set -x
fi

# Install Libra components necessary for analytics workload

install_dir=~/bin

# Skip the package install stuff if so directed
if ! [[ -n "$LIBRA_INSTALL_SKIP_PACKAGES" ]]; then

# First display a reasonable warning to the user unless run with -y
if ! [[ $# -eq 1 && $1 == "-y" ]]; then
  echo "**************************************************************************************"
  echo "This script requires sudo privilege. It installs utilities"
  echo "into: ${install_dir}. It also *removes* any existing docker installed on"
  echo "this machine and then installs the latest docker release as well as other"
  echo "required packages."
  echo "Only proceed if you are sure you want to make those changes to this machine."
  echo "**************************************************************************************"
  read -p "Are you sure you want to proceed? " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Determine if we are on Debian or Ubuntu
linux_distro=$(lsb_release -a 2>/dev/null | grep "^Distributor ID:" | cut -f 2)
# Some systems don't have lsb_release installed (e.g. ChromeOS) and so we try to
# use /etc/os-release instead
if [[ -z "$linux_distro" ]]; then
  if [[ -f "/etc/os-release" ]]; then
    distro_name_string=$(grep "^NAME=" /etc/os-release | cut -d '=' -f 2)
    if [[ $distro_name_string =~ Debian ]]; then
      linux_distro="Debian"
    elif [[ $distro_name_string =~ Ubuntu ]]; then
      linux_distro="Ubuntu"
    fi
  else
    echo "Failed to identify distro: /etc/os-release doesn't exist"
    exit 1
  fi
fi
case $linux_distro in
  Debian)
    echo "Installing docker for Debian"
    ;;
  Ubuntu)
    echo "Installing docker for Ubuntu"
    ;;
  *)
    echo "ERROR: Detected unknown distribution $linux_distro, can't install docker"
    exit 1
    ;;
esac

# dismiss the popups
export DEBIAN_FRONTEND=noninteractive

## https://docs.docker.com/engine/install/ubuntu/
## https://docs.docker.com/engine/install/debian/
## https://superuser.com/questions/518859/ignore-packages-that-are-not-currently-installed-when-using-apt-get-remove1
packages_to_remove="docker docker-engine docker.io containerd runc docker-compose docker-doc podman-docker"
installed_packages_to_remove=""
for package_to_remove in $(echo $packages_to_remove); do
  $(dpkg --info $package_to_remove &> /dev/null)
  if [[ $? -eq 0 ]]; then
    installed_packages_to_remove="$installed_packages_to_remove $package_to_remove"
  fi
done

# Enable stop on error now, since we needed it off for the code above
set -euo pipefail  ## https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

if [[ -n "${installed_packages_to_remove}" ]]; then
  echo "**************************************************************************************"
  echo "Removing existing docker packages"
  sudo apt -y remove $installed_packages_to_remove
fi

echo "**************************************************************************************"
echo "Installing dependencies"
sudo apt -y update
sudo apt -y install jq
sudo apt -y install git
# curl used below
sudo apt -y install curl 
# docker repo add depends on gnupg and updated ca-certificates
sudo apt -y install ca-certificates gnupg

# Add dockerco package repository
# For reasons not obvious, the dockerco instructions for installation on
# Debian and Ubuntu are slightly different here
case $linux_distro in
  Debian)
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    ;;
  Ubuntu)
    sudo mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    ;;
  *)
    echo "ERROR: Detected unknown distribution $linux_distro, can't install docker"
    exit 1
    ;;
esac
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${linux_distro,,} \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Penny in the update jar
sudo apt -y update

echo "**************************************************************************************"
echo "Installing docker"
sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow the current user to use Docker
sudo usermod -aG docker $USER

# Install Rust
echo "Installing Rust toolchain"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
echo "Installed Rust toolchain:"
$HOME/.cargo/bin/rustup show

# Install Libra build dependencies
echo "Installing Libra Rust build dependencies"
sudo apt install -y build-essential lld pkg-config libssl-dev libgmp-dev clang

# Install Java (needed for Neo4j)
echo "Installing Java"
sudo apt install -y openjdk-17-jre-headless
# Check what version we got
echo "Java version:"
java -version

echo "Installing Neo4j"
# Setup Neo4j package registry
wget -O - https://debian.neo4j.com/neotechnology.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/neotechnology.gpg
echo 'deb [signed-by=/etc/apt/keyrings/neotechnology.gpg] https://debian.neo4j.com stable latest' | sudo tee -a /etc/apt/sources.list.d/neo4j.list
sudo apt-get update

# Install Neo4j
# Magic needed first
sudo add-apt-repository -y universe
# Now install the package
sudo apt-get install -y neo4j=1:5.25.1

# End of long if block: Skip the package install stuff if so directed
fi

# Configure Neo4j
# TODO

# Message the user to check docker is working for them
echo "Please log in again (docker will not work in this current shell) then:"
echo "test that docker is correctly installed and working for your user by running the"
echo "command below (it should print a message beginning \"Hello from Docker!\"):"
echo
echo "docker run hello-world"
echo
