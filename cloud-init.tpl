#cloud-config
package_update: true
# NOTE: package_upgrade disabled - it upgrades systemd/dbus which breaks
# firewalld's DBus connection, and can fail on flaky mirrors (kexec-tools).
# The base Oracle Linux image is already patched; specific packages below.
package_upgrade: false

packages:
  - curl
  - wget
  - git
  - vim
  - jq

runcmd:
  # Ensure firewalld is running and wait for it to be ready
  - |
    systemctl enable firewalld --now
    for i in $(seq 1 15); do
      firewall-cmd --state 2>/dev/null && break
      echo "Waiting for firewalld to be ready... ($i/15)"
      sleep 2
    done

  # Configure firewall for K3s
  - firewall-cmd --permanent --add-port=6443/tcp
  - firewall-cmd --permanent --add-port=10250/tcp
  - firewall-cmd --permanent --add-port=8472/udp
  - firewall-cmd --permanent --add-port=51820/udp
  - firewall-cmd --permanent --add-port=51821/udp
%{ if is_control_plane ~}
  - firewall-cmd --permanent --add-port=2379-2380/tcp
%{ endif ~}
  - firewall-cmd --reload

  # Detect public IP (OCI metadata, then fallback to ifconfig.me)
  - |
    PUBLIC_IP=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ 2>/dev/null | jq -r '.[0].publicIp // empty' 2>/dev/null)
    if [ -z "$PUBLIC_IP" ]; then
      PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
    fi
    echo "Detected public IP: $PUBLIC_IP"

  # Install K3s
%{ if is_control_plane ~}
  - |
    INSTALL_ARGS="server --cluster-init --disable traefik"
    if [ -n "$PUBLIC_IP" ]; then
      INSTALL_ARGS="$INSTALL_ARGS --tls-san $PUBLIC_IP"
    fi
    curl -sfL https://get.k3s.io | K3S_TOKEN="${k3s_token}" sh -s - $INSTALL_ARGS
%{ else ~}
  - sleep 60  # Wait for control plane to be ready
  - curl -sfL https://get.k3s.io | K3S_URL="https://${control_plane_ip}:6443" K3S_TOKEN="${k3s_token}" sh -
%{ endif ~}

  # Enable and start K3s
%{ if is_control_plane ~}
  - systemctl enable k3s
  - systemctl start k3s
%{ else ~}
  - systemctl enable k3s-agent
  - systemctl start k3s-agent
%{ endif ~}

final_message: "K3s ${node_role} ${node_name} is ready!"
