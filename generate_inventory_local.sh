#!/bin/bash

cd multinode

vagrant destroy -f || true
sudo virsh net-destroy vagrant-libvirt || true
vagrant up

# Run the virsh command and store the output in a variable
leases=$(sudo virsh net-dhcp-leases --network vagrant-libvirt)

# Remove the header line from the output
leases=$(echo "$leases" | tail -n +3)

# Initialize variables for each group
masters=""
workers=""

# Loop through each line of the output
while IFS= read -r line; do
  # Extract the hostname and IP address from each line
  hostname=$(echo "$line" | awk '{print $6}')
  ip=$(echo "$line" | awk '{print $5}')

  # Determine the group based on the hostname
  if [[ "$hostname" == *"master"* ]]; then
    masters+="${hostname} ansible_ssh_host=$(echo "$ip" | sed 's/\/24//') ansible_become_user=root ansible_port=22 rke2_type=server"$'\n'
  else
    if [[ "$hostname" == *"node"* ]]; then
      workers+="${hostname} ansible_ssh_host=$(echo "$ip" | sed 's/\/24//') ansible_become_user=root ansible_port=22 rke2_type=agent"$'\n'
    fi
  fi

done <<< "$leases"



# Generate the inventory content
inventory_content="[masters]"$'\n'"${masters}"$'\n'"[workers]"$'\n'"${workers}"

cd ..

cat << EOF > inventory.ini
[all:vars]
ansible_user=vagrant
ansible_ssh_common_args="-o StrictHostKeyChecking=no"

$inventory_content

[k8s_cluster:children]
masters
workers

EOF

# ansible-galaxy install -r collections/requirements.yml --ignore-certs

# ansible-playbook site.yml -i inventory/inventory.ini
