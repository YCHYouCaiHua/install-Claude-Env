#!/bin/bash

# XFCE Desktop + RDP Setup Script for Linux
# Compatible with Ubuntu/Debian and CentOS/RHEL/Rocky Linux
# 
# Usage: ./setup_xfce_rdp.sh [OPTIONS]
#        ./setup_xfce_rdp.sh --auto-yes    # Automated installation
# 
# This script will:
# 1. Install XFCE desktop environment
# 2. Install and configure xrdp for remote desktop access
# 3. Configure firewall to allow RDP connections
# 4. Optimize settings for macOS Remote Desktop client
# 
# Requirements:
# - Ubuntu/Debian/CentOS/RHEL/Rocky/Fedora Linux
# - User account with sudo privileges
# - Internet connection for package downloads

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
BACKUP_DIR=""
AUTO_YES="0"

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-yes|-y)
                AUTO_YES="1"
                log "Auto mode enabled: Will skip interactive prompts where possible"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --auto-yes, -y      Skip interactive prompts (recommended for automation)"
                echo "  --help, -h          Show this help message"
                echo
                echo "Environment variables:"
                echo "  AUTO_YES=1          Same as --auto-yes flag"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Please run as a regular user with sudo privileges."
    exit 1
fi

# Check if user has sudo privileges
if ! timeout 1 sudo -n true 2>/dev/null; then
    log "Testing sudo access..."
    if ! sudo -v; then
        error "This script requires sudo privileges. Please ensure you can run sudo commands."
        exit 1
    fi
fi

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        error "Cannot detect Linux distribution"
        exit 1
    fi
    
    log "Detected distribution: $DISTRO $VERSION"
}

# Check for existing installations
check_existing_setup() {
    log "Checking for existing XFCE/RDP installations..."
    
    EXISTING_XFCE=false
    EXISTING_XRDP=false
    EXISTING_CONFIG=false
    
    # Check for XFCE installation
    if command -v xfce4-session >/dev/null 2>&1; then
        EXISTING_XFCE=true
        warn "XFCE desktop environment is already installed"
    fi
    
    # Check for xrdp installation
    if systemctl list-units --full -all | grep -Fq "xrdp.service"; then
        EXISTING_XRDP=true
        warn "xrdp service is already installed"
    elif command -v xrdp >/dev/null 2>&1; then
        EXISTING_XRDP=true
        warn "xrdp binary found but service may not be properly configured"
    fi
    
    # Check for existing configurations
    if [[ -f ~/.xsession ]] || [[ -f ~/.Xclients ]] || [[ -d ~/.config/xfce4 ]]; then
        EXISTING_CONFIG=true
        warn "Existing XFCE configuration found in user directory"
    fi
    
    if [[ -f /etc/xrdp/startwm.sh.backup ]] || [[ -f /etc/xrdp/sesman.ini.backup ]]; then
        EXISTING_CONFIG=true
        warn "Existing xrdp configuration backups found"
    fi
    
    # Report findings
    if [[ $EXISTING_XFCE == true ]] || [[ $EXISTING_XRDP == true ]] || [[ $EXISTING_CONFIG == true ]]; then
        echo
        echo -e "${YELLOW}Existing installation detected:${NC}"
        [[ $EXISTING_XFCE == true ]] && echo "  - XFCE desktop environment"
        [[ $EXISTING_XRDP == true ]] && echo "  - xrdp remote desktop service"
        [[ $EXISTING_CONFIG == true ]] && echo "  - Previous configuration files"
        echo
        return 0
    else
        log "No existing XFCE/RDP installation found. Proceeding with fresh installation."
        return 1
    fi
}

# Backup existing configurations
backup_existing_config() {
    log "Creating backup of existing configurations..."
    
    BACKUP_DIR="$HOME/xfce_rdp_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        error "Failed to create backup directory: $BACKUP_DIR"
        exit 1
    fi
    
    # Backup user configurations
    if [[ -f ~/.xsession ]]; then
        cp ~/.xsession "$BACKUP_DIR/xsession.backup"
        log "Backed up ~/.xsession"
    fi
    
    if [[ -f ~/.Xclients ]]; then
        cp ~/.Xclients "$BACKUP_DIR/Xclients.backup"
        log "Backed up ~/.Xclients"
    fi
    
    if [[ -d ~/.config/xfce4 ]]; then
        cp -r ~/.config/xfce4 "$BACKUP_DIR/xfce4_config.backup"
        log "Backed up ~/.config/xfce4"
    fi
    
    # Backup system configurations
    if [[ -f /etc/xrdp/startwm.sh ]]; then
        sudo cp /etc/xrdp/startwm.sh "$BACKUP_DIR/startwm.sh.backup" && \
        sudo chown $USER:$USER "$BACKUP_DIR/startwm.sh.backup" && \
        log "Backed up /etc/xrdp/startwm.sh"
    fi
    
    if [[ -f /etc/xrdp/xrdp.ini ]]; then
        sudo cp /etc/xrdp/xrdp.ini "$BACKUP_DIR/xrdp.ini.backup" && \
        sudo chown $USER:$USER "$BACKUP_DIR/xrdp.ini.backup" && \
        log "Backed up /etc/xrdp/xrdp.ini"
    fi
    
    if [[ -f /etc/xrdp/sesman.ini ]]; then
        sudo cp /etc/xrdp/sesman.ini "$BACKUP_DIR/sesman.ini.backup" && \
        sudo chown $USER:$USER "$BACKUP_DIR/sesman.ini.backup" && \
        log "Backed up /etc/xrdp/sesman.ini"
    fi
    
    log "Backup completed in: $BACKUP_DIR"
    
    # Create restore script
    cat > "$BACKUP_DIR/restore.sh" << 'RESTORE_EOF'
#!/bin/bash
# Restore script for XFCE/RDP configuration backup

echo "Restoring XFCE/RDP configuration from backup..."

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Stop services
sudo systemctl stop xrdp 2>/dev/null || true
sudo systemctl stop xrdp-sesman 2>/dev/null || true

# Restore user configurations
[[ -f "$SCRIPT_DIR/xsession.backup" ]] && cp "$SCRIPT_DIR/xsession.backup" ~/.xsession
[[ -f "$SCRIPT_DIR/Xclients.backup" ]] && cp "$SCRIPT_DIR/Xclients.backup" ~/.Xclients
[[ -d "$SCRIPT_DIR/xfce4_config.backup" ]] && cp -r "$SCRIPT_DIR/xfce4_config.backup" ~/.config/xfce4

# Restore system configurations
[[ -f "$SCRIPT_DIR/startwm.sh.backup" ]] && sudo cp "$SCRIPT_DIR/startwm.sh.backup" /etc/xrdp/startwm.sh
[[ -f "$SCRIPT_DIR/xrdp.ini.backup" ]] && sudo cp "$SCRIPT_DIR/xrdp.ini.backup" /etc/xrdp/xrdp.ini
[[ -f "$SCRIPT_DIR/sesman.ini.backup" ]] && sudo cp "$SCRIPT_DIR/sesman.ini.backup" /etc/xrdp/sesman.ini

# Fix permissions
sudo chmod +x /etc/xrdp/startwm.sh 2>/dev/null || true

# Restart services
sudo systemctl enable xrdp 2>/dev/null || true
sudo systemctl start xrdp 2>/dev/null || true
sudo systemctl enable xrdp-sesman 2>/dev/null || true
sudo systemctl start xrdp-sesman 2>/dev/null || true

echo "Configuration restore completed!"
echo "Note: You may need to log out and back in for all changes to take effect."
RESTORE_EOF
    
    chmod +x "$BACKUP_DIR/restore.sh"
    log "Created restore script: $BACKUP_DIR/restore.sh"
    echo
}

# Clean existing configurations
clean_existing_setup() {
    log "Cleaning existing XFCE/RDP configurations..."
    
    # Stop services first
    if systemctl is-active --quiet xrdp; then
        log "Stopping xrdp service..."
        sudo systemctl stop xrdp
    fi
    
    if systemctl is-active --quiet xrdp-sesman; then
        log "Stopping xrdp-sesman service..."
        sudo systemctl stop xrdp-sesman
    fi
    
    # Clean user configurations
    log "Removing user configuration files..."
    [[ -f ~/.xsession ]] && rm -f ~/.xsession
    [[ -f ~/.Xclients ]] && rm -f ~/.Xclients
    
    # Reset XFCE configuration (keep backup in case user wants to restore)
    if [[ -d ~/.config/xfce4 ]]; then
        rm -rf ~/.config/xfce4
        log "Reset XFCE user configuration"
    fi
    
    # Reset xrdp configurations to defaults
    if [[ -f /etc/xrdp/startwm.sh ]]; then
        log "Resetting xrdp startwm.sh to default..."
        # Try to restore from original if exists, otherwise use generic default
        if [[ -f /etc/xrdp/startwm.sh.orig ]]; then
            sudo cp /etc/xrdp/startwm.sh.orig /etc/xrdp/startwm.sh
        else
            sudo bash -c 'cat > /etc/xrdp/startwm.sh << "EOF"
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
exec /etc/X11/Xsession
EOF'
        fi
        sudo chmod +x /etc/xrdp/startwm.sh
    fi
    
    # Restore original xrdp.ini if backup exists
    if [[ -f /etc/xrdp/xrdp.ini.orig ]]; then
        sudo cp /etc/xrdp/xrdp.ini.orig /etc/xrdp/xrdp.ini
    fi
    
    # Restore original sesman.ini if backup exists  
    if [[ -f /etc/xrdp/sesman.ini.orig ]]; then
        sudo cp /etc/xrdp/sesman.ini.orig /etc/xrdp/sesman.ini
    fi
    
    # Remove polkit configurations we might have added
    if [[ -f /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla ]]; then
        sudo rm -f /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
        log "Removed custom polkit configuration"
    fi
    
    log "Existing configuration cleanup completed"
    echo
}

# Handle existing installation
handle_existing_installation() {
    if check_existing_setup; then
        if [[ "$AUTO_YES" == "1" ]]; then
            log "Auto mode: Automatically choosing to clean and reconfigure existing installation"
            backup_existing_config
            clean_existing_setup
            return 0
        fi
        
        echo -e "${YELLOW}How would you like to proceed?${NC}"
        echo "1) Clean and reconfigure (recommended)"
        echo "2) Keep existing and try to upgrade/fix"
        echo "3) Exit without changes"
        echo
        read -p "Please choose an option (1/2/3): " choice
        
        case $choice in
            1)
                log "Selected: Clean and reconfigure"
                backup_existing_config
                clean_existing_setup
                return 0
                ;;
            2)
                warn "Selected: Keep existing configuration"
                warn "This may cause conflicts or unexpected behavior"
                read -p "Are you sure you want to continue? (y/N): " confirm
                if [[ ! $confirm =~ ^[Yy]$ ]]; then
                    log "Installation cancelled"
                    exit 0
                fi
                return 0
                ;;
            3)
                log "Installation cancelled by user"
                exit 0
                ;;
            *)
                error "Invalid choice. Installation cancelled."
                exit 1
                ;;
        esac
    fi
    return 0
}

# Update system packages
update_system() {
    log "Updating system packages..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt update
            sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
            ;;
        centos|rhel|rocky|almalinux)
            sudo yum update -y
            ;;
        fedora)
            sudo dnf update -y
            ;;
        *)
            error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Install XFCE and required packages
install_packages() {
    log "Installing XFCE desktop environment and RDP server..."
    
    case $DISTRO in
        ubuntu|debian)
            # Install core packages first
            sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                xfce4 \
                xfce4-goodies \
                xrdp \
                dbus-x11 \
                firefox \
                thunar \
                network-manager-gnome \
                pulseaudio \
                pavucontrol \
                xfce4-terminal \
                mousepad \
                ristretto \
                xfce4-screenshooter \
                fonts-noto \
                fonts-noto-cjk \
                gvfs \
                gvfs-backends \
                at-spi2-core \
                netcat-openbsd \
                net-tools
            
            # Try to install pulseaudio-module-xrdp if available
            if apt-cache search pulseaudio-module-xrdp | grep -q pulseaudio-module-xrdp; then
                log "Installing pulseaudio-module-xrdp for audio support..."
                sudo DEBIAN_FRONTEND=noninteractive apt install -y pulseaudio-module-xrdp
            else
                warn "pulseaudio-module-xrdp not available, will configure manual audio support"
                # Install alternative audio packages
                sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                    pulseaudio-utils \
                    alsa-utils || true
            fi
            ;;
        centos|rhel|rocky|almalinux)
            # Enable EPEL repository
            sudo yum install -y epel-release
            sudo yum groupinstall -y "Xfce"
            sudo yum install -y \
                xrdp \
                firefox \
                thunar \
                pulseaudio \
                pavucontrol \
                xfce4-terminal \
                mousepad
            ;;
        fedora)
            sudo dnf groupinstall -y "Xfce Desktop"
            sudo dnf install -y \
                xrdp \
                firefox \
                thunar \
                pulseaudio \
                pavucontrol \
                xfce4-terminal \
                mousepad
            ;;
    esac
}

# Configure XFCE session
configure_xfce() {
    log "Configuring XFCE session..."
    
    # Disable Wayland for Ubuntu 22.04+ (forces X11)
    if [[ $DISTRO == "ubuntu" && $(echo $VERSION | cut -d. -f1) -ge 22 ]]; then
        log "Configuring GDM to use X11 (disabling Wayland for better RDP compatibility)"
        sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf 2>/dev/null || true
        # Also set default session to XFCE
        sudo update-alternatives --set x-session-manager /usr/bin/xfce4-session 2>/dev/null || true
    fi
    
    # Create .xsession file for the current user
    echo "xfce4-session" > ~/.xsession
    chmod +x ~/.xsession
    
    # Create .Xclients file as backup
    echo "exec xfce4-session" > ~/.Xclients
    chmod +x ~/.Xclients
    
    # Configure XFCE to start properly with xrdp
    mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
    
    # Disable compositing for better RDP performance
    cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
  </property>
</channel>
EOF
}

# Configure xrdp
configure_xrdp() {
    log "Configuring xrdp..."
    
    # Create backup of original configurations if they don't exist
    if [[ -f /etc/xrdp/xrdp.ini ]] && [[ ! -f /etc/xrdp/xrdp.ini.orig ]]; then
        sudo cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.orig
        log "Created backup of original xrdp.ini"
    fi
    
    if [[ -f /etc/xrdp/sesman.ini ]] && [[ ! -f /etc/xrdp/sesman.ini.orig ]]; then
        sudo cp /etc/xrdp/sesman.ini /etc/xrdp/sesman.ini.orig
        log "Created backup of original sesman.ini"
    fi
    
    # Create xrdp configuration
    sudo bash -c 'cat > /etc/xrdp/startwm.sh << "EOF"
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi

# Start dbus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# Start XFCE session
exec xfce4-session
EOF'
    
    sudo chmod +x /etc/xrdp/startwm.sh
    
    # Configure audio for RDP sessions
    configure_rdp_audio
    
    # Configure xrdp.ini for better performance
    sudo sed -i 's/max_bpp=32/max_bpp=24/' /etc/xrdp/xrdp.ini
    sudo sed -i 's/#tcp_nodelay=1/tcp_nodelay=1/' /etc/xrdp/xrdp.ini
    sudo sed -i 's/#tcp_keepalive=1/tcp_keepalive=1/' /etc/xrdp/xrdp.ini
    
    # Backup original sesman.ini and configure it
    sudo cp /etc/xrdp/sesman.ini /etc/xrdp/sesman.ini.backup
    sudo sed -i 's/#EnableUserWindowManager=1/EnableUserWindowManager=1/' /etc/xrdp/sesman.ini
    sudo sed -i 's/#UserWindowManager=startwm.sh/UserWindowManager=startwm.sh/' /etc/xrdp/sesman.ini
    
    # Add current user to required groups (Ubuntu specific)
    if getent group ssl-cert >/dev/null 2>&1; then
        sudo adduser $USER ssl-cert || warn "Failed to add user to ssl-cert group"
    fi
    if getent group xrdp >/dev/null 2>&1; then
        sudo usermod -a -G xrdp $USER || warn "Failed to add user to xrdp group"
    fi
    
    # Fix polkit permissions for Ubuntu
    sudo mkdir -p /etc/polkit-1/localauthority/50-local.d
    sudo bash -c 'cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla << "POLKIT_EOF"
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
POLKIT_EOF'
}

# Configure audio for RDP sessions
configure_rdp_audio() {
    log "Configuring audio support for RDP sessions..."
    
    # Check if pulseaudio-module-xrdp is installed
    if dpkg -l | grep -q pulseaudio-module-xrdp; then
        log "pulseaudio-module-xrdp is installed, using advanced audio configuration"
        
        # Enable xrdp sound module in pulse
        sudo sed -i '/^load-module module-native-protocol-unix/a load-module module-xrdp-sink\nload-module module-xrdp-source' /etc/pulse/default.pa 2>/dev/null || true
        
    else
        log "Setting up basic audio configuration without pulseaudio-module-xrdp"
        
        # Create pulse configuration for RDP users
        sudo mkdir -p /etc/pulse/client.conf.d
        sudo bash -c 'cat > /etc/pulse/client.conf.d/00-disable-autospawn.conf << "PULSE_EOF"
# Disable autospawn for RDP sessions to prevent conflicts
autospawn = no
PULSE_EOF'
        
        # Create script to start pulseaudio in user sessions
        sudo bash -c 'cat > /usr/local/bin/rdp-pulseaudio-start << "PULSE_SCRIPT_EOF"
#!/bin/bash
# Start PulseAudio for RDP session if not running

if ! pgrep -u $USER pulseaudio >/dev/null; then
    pulseaudio --start --log-target=syslog &
    sleep 1
fi
PULSE_SCRIPT_EOF'
        
        sudo chmod +x /usr/local/bin/rdp-pulseaudio-start
        
        # Add pulseaudio startup to user session
        mkdir -p ~/.config/autostart
        cat > ~/.config/autostart/pulseaudio-rdp.desktop << 'AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=PulseAudio for RDP
Exec=/usr/local/bin/rdp-pulseaudio-start
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
AUTOSTART_EOF
    fi
    
    # Ensure user is in audio group
    sudo usermod -a -G audio $USER || warn "Failed to add user to audio group"
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    # Check if firewalld is running
    if systemctl is-active --quiet firewalld; then
        log "Configuring firewalld..."
        sudo firewall-cmd --permanent --add-port=3389/tcp
        sudo firewall-cmd --reload
    # Check if ufw is available (Ubuntu default)
    elif command -v ufw >/dev/null 2>&1; then
        log "Configuring ufw..."
        sudo ufw --force enable || warn "Failed to enable ufw"
        sudo ufw allow 3389/tcp || warn "Failed to allow RDP port in ufw"
        sudo ufw allow OpenSSH || warn "Failed to allow SSH port in ufw"
    # Check if iptables is available
    elif command -v iptables >/dev/null 2>&1; then
        log "Configuring iptables..."
        sudo iptables -A INPUT -p tcp --dport 3389 -j ACCEPT
        # Try to save iptables rules (different methods for different distros)
        if command -v iptables-save >/dev/null 2>&1; then
            sudo mkdir -p /etc/iptables 2>/dev/null || true
            sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null 2>&1 || true
            # Try netfilter-persistent method
            if command -v netfilter-persistent >/dev/null 2>&1; then
                sudo netfilter-persistent save 2>/dev/null || true
            fi
            # Try iptables-persistent method  
            if [ -f /etc/init.d/iptables-persistent ]; then
                sudo /etc/init.d/iptables-persistent save 2>/dev/null || true
            fi
        fi
    else
        warn "No firewall detected. Please manually open port 3389/tcp"
    fi
}

# Start and enable services
start_services() {
    log "Starting and enabling services..."
    
    sudo systemctl enable xrdp
    sudo systemctl start xrdp
    sudo systemctl enable xrdp-sesman
    sudo systemctl start xrdp-sesman
    
    # Check if services are running
    if systemctl is-active --quiet xrdp; then
        log "xrdp service is running"
    else
        error "Failed to start xrdp service"
        exit 1
    fi
}

# Create RDP user if needed
create_rdp_user() {
    echo
    
    # Check for auto mode
    if [[ "$AUTO_YES" == "1" ]]; then
        log "Auto mode: Creating dedicated RDP user 'user110'"
        rdp_username="user110"
        rdp_password="111111"
        
        # Check if user already exists
        if id "$rdp_username" &>/dev/null; then
            warn "User '$rdp_username' already exists. Updating password and configuration..."
            echo "$rdp_username:$rdp_password" | sudo chpasswd
        else
            # Create new user
            sudo useradd -m -s /bin/bash "$rdp_username"
            echo "$rdp_username:$rdp_password" | sudo chpasswd
            log "Created RDP user '$rdp_username'"
        fi
        
        # Clear password from memory for security
        rdp_password=""
        
        # Add user to required groups for Ubuntu
        sudo usermod -a -G audio "$rdp_username" || warn "Failed to add $rdp_username to audio group"
        if getent group ssl-cert >/dev/null 2>&1; then
            sudo adduser "$rdp_username" ssl-cert || warn "Failed to add $rdp_username to ssl-cert group"
        fi
        
        # Configure XFCE for new user
        sudo -u "$rdp_username" bash -c "
            echo 'xfce4-session' > /home/$rdp_username/.xsession
            chmod +x /home/$rdp_username/.xsession
            echo 'exec xfce4-session' > /home/$rdp_username/.Xclients
            chmod +x /home/$rdp_username/.Xclients
            mkdir -p /home/$rdp_username/.config/xfce4/xfconf/xfce-perchannel-xml
            cat > /home/$rdp_username/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'XFCE_EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<channel name=\"xfwm4\" version=\"1.0\">
  <property name=\"general\" type=\"empty\">
    <property name=\"use_compositing\" type=\"bool\" value=\"false\"/>
  </property>
</channel>
XFCE_EOF
        "
        
        # Configure audio for new RDP user
        if ! dpkg -l | grep -q pulseaudio-module-xrdp; then
            log "Configuring audio for RDP user '$rdp_username'"
            sudo -u "$rdp_username" bash -c "
                mkdir -p /home/$rdp_username/.config/autostart
                cat > /home/$rdp_username/.config/autostart/pulseaudio-rdp.desktop << 'USER_AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=PulseAudio for RDP
Exec=/usr/local/bin/rdp-pulseaudio-start
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
USER_AUTOSTART_EOF
            "
        fi
        
        log "RDP user 'user110' configured successfully"
        return 0
    fi
    
    read -p "Do you want to create a dedicated RDP user? (y/N): " create_user
    if [[ $create_user =~ ^[Yy]$ ]]; then
        read -p "Enter username for RDP user: " rdp_username
        
        # Check if user already exists
        if id "$rdp_username" &>/dev/null; then
            warn "User '$rdp_username' already exists. Skipping user creation."
            return
        fi
        
        read -s -p "Enter password for RDP user: " rdp_password
        echo
        read -s -p "Confirm password: " rdp_password_confirm
        echo
        
        if [ "$rdp_password" != "$rdp_password_confirm" ]; then
            error "Passwords do not match!"
            return
        fi
        
        sudo useradd -m -s /bin/bash "$rdp_username"
        echo "$rdp_username:$rdp_password" | sudo chpasswd
        
        # Clear password from memory for security
        rdp_password=""
        rdp_password_confirm=""
        
        # Add user to required groups for Ubuntu
        sudo usermod -a -G audio "$rdp_username" || warn "Failed to add $rdp_username to audio group"
        if getent group ssl-cert >/dev/null 2>&1; then
            sudo adduser "$rdp_username" ssl-cert || warn "Failed to add $rdp_username to ssl-cert group"
        fi
        
        # Configure XFCE for new user
        sudo -u "$rdp_username" bash -c "
            echo 'xfce4-session' > /home/$rdp_username/.xsession
            chmod +x /home/$rdp_username/.xsession
            echo 'exec xfce4-session' > /home/$rdp_username/.Xclients
            chmod +x /home/$rdp_username/.Xclients
            mkdir -p /home/$rdp_username/.config/xfce4/xfconf/xfce-perchannel-xml
            cat > /home/$rdp_username/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'XFCE_EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<channel name=\"xfwm4\" version=\"1.0\">
  <property name=\"general\" type=\"empty\">
    <property name=\"use_compositing\" type=\"bool\" value=\"false\"/>
  </property>
</channel>
XFCE_EOF
        "
        
        # Configure audio for new RDP user
        if ! dpkg -l | grep -q pulseaudio-module-xrdp; then
            log "Configuring audio for RDP user '$rdp_username'"
            sudo -u "$rdp_username" bash -c "
                mkdir -p /home/$rdp_username/.config/autostart
                cat > /home/$rdp_username/.config/autostart/pulseaudio-rdp.desktop << 'USER_AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=PulseAudio for RDP
Exec=/usr/local/bin/rdp-pulseaudio-start
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
USER_AUTOSTART_EOF
            "
        fi
        
        log "RDP user '$rdp_username' created successfully"
    fi
}

# Test network connectivity and services
test_connectivity() {
    log "Testing network connectivity and services..."
    
    # Wait for services to fully start
    sleep 3
    
    # Check if port 3389 is listening
    if command -v ss >/dev/null 2>&1; then
        if ss -tlnp | grep -q ":3389"; then
            log "Port 3389 is listening correctly"
        else
            warn "Port 3389 is not listening. RDP service may have issues."
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tlnp | grep -q ":3389"; then
            log "Port 3389 is listening correctly"
        else
            warn "Port 3389 is not listening. RDP service may have issues."
        fi
    else
        warn "Cannot check port status (ss or netstat not available)"
    fi
    
    # Test local RDP connection
    if command -v nc >/dev/null 2>&1; then
        if timeout 5 nc -z localhost 3389 >/dev/null 2>&1; then
            log "Local RDP connection test: SUCCESS"
        else
            warn "Local RDP connection test: FAILED"
        fi
    fi
}

# Display connection information
display_connection_info() {
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  RDP CONNECTION INFORMATION${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    echo -e "${GREEN}Server IP Address:${NC} $(hostname -I | awk '{print $1}')"
    echo -e "${GREEN}RDP Port:${NC} 3389"
    echo -e "${GREEN}Desktop Environment:${NC} XFCE4"
    echo
    echo -e "${YELLOW}macOS Microsoft Remote Desktop Setup:${NC}"
    echo "1. Open Microsoft Remote Desktop app"
    echo "2. Click 'Add PC'"
    echo "3. Enter PC name: $(hostname -I | awk '{print $1}')"
    if [[ "$AUTO_YES" == "1" ]]; then
        echo "4. User account: Use 'user110' with password '111111'"
    else
        echo "4. User account: Add user account with your Linux username"
    fi
    echo "5. Click 'Save'"
    echo
    echo -e "${YELLOW}Available user accounts:${NC}"
    echo "- Current user: $USER"
    if [[ "$AUTO_YES" == "1" ]]; then
        echo "- RDP user: user110 (password: 111111)"
    elif [[ -n "$rdp_username" ]]; then
        echo "- RDP user: $rdp_username"
    fi
    echo
    echo -e "${YELLOW}Connection Quality Settings for macOS:${NC}"
    echo "- Resolution: 1920x1080 (or match your display)"
    echo "- Color Depth: 24-bit"
    echo "- Enable 'Use all displays' if you have multiple monitors"
    echo "- For best performance: Disable wallpaper and visual effects"
    echo
    echo -e "${YELLOW}Troubleshooting Tips:${NC}"
    echo "- If desktop appears black: sudo systemctl restart xrdp"
    echo "- If connection rejected: Check ufw status and xrdp service"
    if dpkg -l | grep -q pulseaudio-module-xrdp; then
        echo "- Audio: pulseaudio-module-xrdp is installed for optimal audio"
    else
        echo "- Audio: Basic audio configured, restart session if no sound"
        echo "- Audio: Check 'pulseaudio --start' in RDP session if needed"
    fi
    echo "- Check logs: journalctl -u xrdp -f"
    echo "- For Ubuntu 22.04+: May need to disable Wayland (already handled)"
    echo
    echo -e "${GREEN}Service Status:${NC}"
    systemctl status xrdp --no-pager -l
    echo
    echo -e "${GREEN}Setup completed successfully!${NC}"
    echo "You can now connect from your macOS using Microsoft Remote Desktop app."
}

# Completely purge all desktop environments and RDP configurations
purge_all_desktop_environments() {
    echo
    echo -e "${RED}================================${NC}"
    echo -e "${RED}  DESKTOP ENVIRONMENT PURGE${NC}"
    echo -e "${RED}================================${NC}"
    echo
    warn "This operation will completely remove the following:"
    echo "  • All desktop environment packages (XFCE, GNOME, KDE, LXDE, etc.)"
    echo "  • All RDP configurations and services"
    echo "  • All user desktop configuration files"
    echo "  • System desktop-related configurations"
    echo "  • Auto-created RDP users (like user110)"
    echo "  • Package caches and orphaned packages"
    echo
    echo -e "${RED}WARNING: This operation is IRREVERSIBLE!${NC}"
    echo
    
    read -p "Are you sure you want to continue? Please type 'YES' to confirm: " confirm
    if [[ "$confirm" != "YES" ]]; then
        log "Purge operation cancelled"
        exit 0
    fi
    
    log "Starting complete desktop environment purge..."
    
    # Stop all related services
    log "Stopping desktop-related services..."
    sudo systemctl stop xrdp 2>/dev/null || true
    sudo systemctl stop xrdp-sesman 2>/dev/null || true
    sudo systemctl stop lightdm 2>/dev/null || true
    sudo systemctl stop gdm3 2>/dev/null || true
    sudo systemctl stop sddm 2>/dev/null || true
    sudo systemctl stop lxdm 2>/dev/null || true
    
    sudo systemctl disable xrdp 2>/dev/null || true
    sudo systemctl disable xrdp-sesman 2>/dev/null || true
    sudo systemctl disable lightdm 2>/dev/null || true
    sudo systemctl disable gdm3 2>/dev/null || true
    sudo systemctl disable sddm 2>/dev/null || true
    sudo systemctl disable lxdm 2>/dev/null || true
    
    # Remove auto-created RDP users
    log "Removing auto-created RDP users..."
    if id "user110" &>/dev/null; then
        log "Removing user110..."
        sudo pkill -u user110 2>/dev/null || true
        sudo userdel -r user110 2>/dev/null || true
        log "User user110 removed"
    fi
    
    # Detect distribution for appropriate package manager
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        error "Cannot detect Linux distribution"
        exit 1
    fi
    
    # Uninstall all desktop environments based on distribution
    log "Uninstalling desktop environment packages..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo DEBIAN_FRONTEND=noninteractive apt remove --purge -y \
                xfce4* \
                xfce4-goodies* \
                openbox* \
                obconf \
                obmenu \
                tint2 \
                lxde* \
                gnome* \
                kde* \
                unity* \
                mate* \
                cinnamon* \
                xrdp* \
                lightdm* \
                gdm3* \
                sddm* \
                lxdm* \
                pcmanfm \
                thunar \
                lxterminal \
                xfce4-terminal \
                leafpad \
                mousepad \
                ristretto \
                xfce4-screenshooter \
                pavucontrol \
                pulseaudio-module-xrdp \
                network-manager-gnome \
                at-spi2-core \
                gvfs \
                gvfs-backends \
                2>/dev/null || true
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf groupremove -y "Xfce Desktop" "GNOME Desktop" "KDE Plasma Workspaces" 2>/dev/null || true
                sudo dnf remove -y xrdp firefox thunar pulseaudio pavucontrol mousepad 2>/dev/null || true
            elif command -v yum >/dev/null 2>&1; then
                sudo yum groupremove -y "Xfce" "GNOME Desktop" "KDE Plasma Workspaces" 2>/dev/null || true
                sudo yum remove -y xrdp firefox thunar pulseaudio pavucontrol mousepad 2>/dev/null || true
            fi
            ;;
    esac
    
    # Clean orphaned packages and dependencies
    log "Cleaning orphaned packages..."
    case $DISTRO in
        ubuntu|debian)
            sudo apt autoremove --purge -y
            sudo apt autoclean
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf autoremove -y
                sudo dnf clean all
            elif command -v yum >/dev/null 2>&1; then
                sudo yum autoremove -y
                sudo yum clean all
            fi
            ;;
    esac
    
    # Clean user configurations
    log "Cleaning user desktop configurations..."
    
    # Clean current user's configurations
    [[ -f ~/.xsession ]] && rm -f ~/.xsession && log "Removed ~/.xsession"
    [[ -f ~/.Xclients ]] && rm -f ~/.Xclients && log "Removed ~/.Xclients"
    [[ -d ~/.config/xfce4 ]] && rm -rf ~/.config/xfce4 && log "Removed ~/.config/xfce4"
    [[ -d ~/.config/openbox ]] && rm -rf ~/.config/openbox && log "Removed ~/.config/openbox"
    [[ -d ~/.config/tint2 ]] && rm -rf ~/.config/tint2 && log "Removed ~/.config/tint2"
    [[ -d ~/.config/lxpanel ]] && rm -rf ~/.config/lxpanel && log "Removed ~/.config/lxpanel"
    [[ -d ~/.config/lxsession ]] && rm -rf ~/.config/lxsession && log "Removed ~/.config/lxsession"
    [[ -d ~/.config/autostart ]] && rm -rf ~/.config/autostart && log "Removed ~/.config/autostart"
    [[ -d ~/.config/Thunar ]] && rm -rf ~/.config/Thunar && log "Removed ~/.config/Thunar"
    [[ -d ~/.config/xfce4-session ]] && rm -rf ~/.config/xfce4-session && log "Removed ~/.config/xfce4-session"
    
    # Clean other desktop-related configurations
    [[ -f ~/.dmrc ]] && rm -f ~/.dmrc && log "Removed ~/.dmrc"
    [[ -f ~/.xprofile ]] && rm -f ~/.xprofile && log "Removed ~/.xprofile"
    [[ -f ~/.xinitrc ]] && rm -f ~/.xinitrc && log "Removed ~/.xinitrc"
    [[ -f ~/.gtkrc-2.0 ]] && rm -f ~/.gtkrc-2.0 && log "Removed ~/.gtkrc-2.0"
    [[ -d ~/.themes ]] && rm -rf ~/.themes && log "Removed ~/.themes"
    [[ -d ~/.icons ]] && rm -rf ~/.icons && log "Removed ~/.icons"
    
    # Clean all users' configurations (requires sudo)
    log "Cleaning system-wide desktop configurations..."
    for user_home in /home/*; do
        if [[ -d "$user_home" ]]; then
            username=$(basename "$user_home")
            if id "$username" &>/dev/null; then
                log "Cleaning desktop configs for user $username..."
                sudo rm -rf "$user_home/.config/xfce4" 2>/dev/null || true
                sudo rm -rf "$user_home/.config/openbox" 2>/dev/null || true
                sudo rm -rf "$user_home/.config/tint2" 2>/dev/null || true
                sudo rm -rf "$user_home/.config/lxpanel" 2>/dev/null || true
                sudo rm -rf "$user_home/.config/lxsession" 2>/dev/null || true
                sudo rm -rf "$user_home/.config/autostart" 2>/dev/null || true
                sudo rm -rf "$user_home/.config/Thunar" 2>/dev/null || true
                sudo rm -rf "$user_home/.config/xfce4-session" 2>/dev/null || true
                sudo rm -f "$user_home/.xsession" 2>/dev/null || true
                sudo rm -f "$user_home/.Xclients" 2>/dev/null || true
                sudo rm -f "$user_home/.dmrc" 2>/dev/null || true
                sudo rm -f "$user_home/.xprofile" 2>/dev/null || true
                sudo rm -f "$user_home/.xinitrc" 2>/dev/null || true
                sudo rm -f "$user_home/.gtkrc-2.0" 2>/dev/null || true
                sudo rm -rf "$user_home/.themes" 2>/dev/null || true
                sudo rm -rf "$user_home/.icons" 2>/dev/null || true
            fi
        fi
    done
    
    # Clean system configurations
    log "Cleaning system configuration files..."
    sudo rm -rf /etc/xrdp 2>/dev/null || true
    sudo rm -rf /var/lib/xrdp 2>/dev/null || true
    sudo rm -rf /var/log/xrdp 2>/dev/null || true
    sudo rm -rf /etc/xfce4 2>/dev/null || true
    sudo rm -rf /etc/openbox 2>/dev/null || true
    sudo rm -rf /usr/share/xfce4 2>/dev/null || true
    sudo rm -f /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla 2>/dev/null || true
    sudo rm -f /usr/local/bin/rdp-pulseaudio-start 2>/dev/null || true
    
    # Clean systemd service files
    sudo rm -f /etc/systemd/system/xrdp.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/xrdp-sesman.service 2>/dev/null || true
    sudo systemctl daemon-reload
    
    # Clean backup files
    log "Cleaning backup files..."
    rm -rf "$HOME"/xfce_rdp_backup_* 2>/dev/null || true
    rm -rf "$HOME"/openbox_rdp_backup_* 2>/dev/null || true
    rm -rf "$HOME"/desktop_backup_* 2>/dev/null || true
    
    # Clean temporary files
    sudo rm -rf /tmp/.X* 2>/dev/null || true
    sudo rm -rf /tmp/.tint2-* 2>/dev/null || true
    sudo rm -rf /tmp/xfce4-* 2>/dev/null || true
    sudo rm -rf /tmp/.ICE-unix/* 2>/dev/null || true
    
    # Reset default display manager
    log "Resetting display manager settings..."
    if [[ -f /etc/X11/default-display-manager ]]; then
        sudo rm -f /etc/X11/default-display-manager
        log "Removed default display manager setting"
    fi
    
    # Clean firewall rules (RDP port only)
    log "Cleaning RDP firewall rules..."
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw delete allow 3389/tcp 2>/dev/null || true
        log "Removed ufw RDP rule"
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --permanent --remove-port=3389/tcp 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        log "Removed firewalld RDP rule"
    fi
    
    # Clean software sources (if any special sources were added)
    log "Cleaning possible added software sources..."
    sudo rm -f /etc/apt/sources.list.d/xfce* 2>/dev/null || true
    sudo rm -f /etc/apt/sources.list.d/openbox* 2>/dev/null || true
    
    # Final cleanup
    log "Performing final cleanup..."
    case $DISTRO in
        ubuntu|debian)
            sudo apt update 2>/dev/null || true
            sudo apt autoremove --purge -y 2>/dev/null || true
            sudo apt autoclean 2>/dev/null || true
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf autoremove -y 2>/dev/null || true
                sudo dnf clean all 2>/dev/null || true
            elif command -v yum >/dev/null 2>&1; then
                sudo yum autoremove -y 2>/dev/null || true
                sudo yum clean all 2>/dev/null || true
            fi
            ;;
    esac
    
    # Clean snap packages (if any)
    if command -v snap >/dev/null 2>&1; then
        log "Cleaning related snap packages..."
        sudo snap remove firefox 2>/dev/null || true
    fi
    
    # Clean flatpak packages (if any)
    if command -v flatpak >/dev/null 2>&1; then
        log "Cleaning related flatpak packages..."
        flatpak uninstall --unused -y 2>/dev/null || true
    fi
    
    echo
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  PURGE COMPLETED${NC}"
    echo -e "${GREEN}================================${NC}"
    echo
    log "✓ Desktop environment purge completed successfully!"
    echo
    echo -e "${YELLOW}Purge Summary:${NC}"
    echo "• Stopped and disabled all desktop-related services"
    echo "• Uninstalled all desktop environment packages"
    echo "• Removed all user desktop configuration files"
    echo "• Cleaned system configuration files"
    echo "• Removed auto-created RDP users"
    echo "• Cleaned package caches and orphaned packages"
    echo "• Reset firewall RDP rules"
    echo
    echo -e "${BLUE}Recommended Actions:${NC}"
    echo "1. Reboot the system to ensure all changes take effect"
    echo "2. Check disk space has been freed: df -h"
    echo "3. To reinstall desktop environment, re-run this script"
    echo
    
    # Show disk usage
    echo -e "${GREEN}Current Disk Usage:${NC}"
    df -h / 2>/dev/null || true
    echo
    
    log "System has been restored to a clean state without desktop environments"
}

# Display main menu and handle user selection
show_main_menu() {
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  XFCE + RDP Setup Script${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    echo "Please select what you would like to do:"
    echo
    echo "1) Install XFCE Desktop + RDP Server"
    echo "2) Completely remove all desktop environments and RDP"
    echo "3) Exit"
    echo
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1)
            log "Selected: Install XFCE Desktop + RDP Server"
            install_xfce_rdp
            ;;
        2)
            log "Selected: Completely remove all desktop environments"
            purge_all_desktop_environments
            ;;
        3)
            log "Exiting script"
            exit 0
            ;;
        *)
            error "Invalid choice. Please select 1, 2, or 3."
            show_main_menu
            ;;
    esac
}

# Install XFCE + RDP function (original main functionality)
install_xfce_rdp() {
    log "Starting XFCE + RDP installation..."
    
    detect_distro
    handle_existing_installation
    update_system
    install_packages
    configure_xfce
    configure_xrdp
    configure_firewall
    start_services
    create_rdp_user
    test_connectivity
    display_connection_info
    
    # Final verification
    PORT_LISTENING=false
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp | grep -q ":3389" && PORT_LISTENING=true
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tlnp | grep -q ":3389" && PORT_LISTENING=true
    fi
    
    if systemctl is-active --quiet xrdp && [[ $PORT_LISTENING == true ]]; then
        log "✓ XFCE + RDP setup completed successfully!"
        echo
        echo -e "${GREEN}Next steps:${NC}"
        echo "1. Test RDP connection from macOS using Microsoft Remote Desktop"
        echo "2. If this is first desktop installation, consider rebooting"
        if dpkg -l | grep -q pulseaudio-module-xrdp; then
            echo "3. Audio should work automatically with pulseaudio-module-xrdp"
        else
            echo "3. Audio configured with fallback method - may need session restart for sound"
        fi
        
        if [[ "$AUTO_YES" == "1" ]]; then
            echo
            echo -e "${RED}SECURITY NOTICE:${NC}"
            echo -e "${YELLOW}Auto-created RDP user credentials:${NC}"
            echo "  Username: user110"
            echo "  Password: 111111"
            echo "  ${RED}WARNING: Change this password after first login for security!${NC}"
        fi
        
        # Show backup information if backup was created
        if [[ -n "$BACKUP_DIR" ]] && [[ -d "$BACKUP_DIR" ]]; then
            echo
            echo -e "${BLUE}Backup Information:${NC}"
            echo "Previous configuration backed up to: $BACKUP_DIR"
            echo "To restore previous configuration, run: $BACKUP_DIR/restore.sh"
        fi
    else
        error "Setup completed but services may not be running correctly"
        echo "Please check: sudo systemctl status xrdp"
        exit 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    show_main_menu
}

# Run main function
main "$@"