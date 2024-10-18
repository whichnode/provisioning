#!/usr/bin/env bash
if [[ -n "$LIBRA_SCRIPT_DEBUG" ]]; then
    set -x
fi

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
    echo "Installing k3s for Debian"
    ;;
  Ubuntu)
    echo "Installing k3s for Ubuntu"
    ;;
  *)
    echo "ERROR: Detected unknown distribution $linux_distro, can't install k3s"
    exit 1
    ;;
esac

# dismiss the popups
export DEBIAN_FRONTEND=noninteractive

## Even though we're installing k3s, which doesn't depend on docker, we still un-install any distro-origin docker components first
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
sudo apt -y install curl
# Install Libra build dependencies
sudo apt install -y build-essential lld pkg-config libssl-dev libgmp-dev clang

echo "**************************************************************************************"
echo "Installing k3s"
k3s_installer_file=$HOME/install-k3s.sh
curl -sfL https://get.k3s.io -o ${k3s_installer_file}
chmod +x ${k3s_installer_file}
sudo ${k3s_installer_file}
echo "Installed k3s"

# Install Rust
echo "Installing Rust toolchain"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
echo "Installed Rust toolchain:"
$HOME/.cargo/bin/rustup show

# End of long if block: Skip the package install stuff if so directed
fi

# Message the user to check docker is working for them
echo "Please log in again (docker will not work in this current shell) then:"
echo "test that k3s is correctly installed and working for your user by running the"
echo "command below:"
echo
echo "sudo k3s kubectl get node"
echo
