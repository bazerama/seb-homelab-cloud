#cloud-config
package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - vim
  - htop

runcmd:
  # Install K3s
%{ if is_control_plane ~}
  - curl -sfL https://get.k3s.io | K3S_TOKEN="${k3s_token}" sh -s - server --cluster-init --disable traefik
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

  # Configure firewall for K3s (Ubuntu uses ufw)
  - ufw allow 22/tcp
  - ufw allow 6443/tcp
  - ufw allow 10250/tcp
  - ufw allow 8472/udp
  - ufw allow 51820/udp
  - ufw allow 51821/udp
%{ if is_control_plane ~}
  - ufw allow 2379:2380/tcp
%{ endif ~}
  - ufw --force enable

final_message: "K3s ${node_role} ${node_name} is ready!"
