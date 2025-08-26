#!/bin/bash

# XFCE Desktop + RDP Setup Script for Linux
# Compatible with Ubuntu/Debian and CentOS/RHEL/Rocky Linux
# 
# Usage: ./setup_xfce_rdp.sh
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
                pulseaudio-module-xrdp \
                netcat-openbsd \
                net-tools
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
    echo "4. User account: Add user account with your Linux username"
    echo "5. Click 'Save'"
    echo
    echo -e "${YELLOW}Available user accounts:${NC}"
    echo "- Current user: $USER"
    if [[ -n "$rdp_username" ]]; then
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
    echo "- For audio issues: pulseaudio-module-xrdp is already installed"
    echo "- Check logs: journalctl -u xrdp -f"
    echo "- For Ubuntu 22.04+: May need to disable Wayland (already handled)"
    echo
    echo -e "${GREEN}Service Status:${NC}"
    systemctl status xrdp --no-pager -l
    echo
    echo -e "${GREEN}Setup completed successfully!${NC}"
    echo "You can now connect from your macOS using Microsoft Remote Desktop app."
}

# Main execution
main() {
    log "Starting XFCE + RDP setup script..."
    
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
        echo "3. For audio support, make sure pulseaudio is running in user session"
        
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

# Run main function
main