#!/bin/bash
# Change Nameserver and Auto Register hostname to dns server even reboot
# 2023/04/27     Jacky-Lin     jackysusu@amigo.com.tw;jackysusu@gmail.com


###  variable  ###
DNS_SERVER=
DOMAIN=
ETH=$(ip route | awk '/default/ { print $5 }')

##################### Change NAMESERVER #####################
# Set DNS server
echo "[Resolve]" | sudo tee /etc/systemd/resolved.conf > /dev/null
echo "DNS=$DNS_SERVER" | sudo tee -a /etc/systemd/resolved.conf > /dev/null
echo "Domains=$DOMAIN" | sudo tee -a /etc/systemd/resolved.conf > /dev/null

# Restart systemd-resolved
sudo systemctl restart systemd-resolved
sudo systemctl enable systemd-resolved
sudo mv /etc/resolv.conf /etc/resolv.conf.bak
sudo ln -s /run/systemd/resolve/resolv.conf /etc/
##############################################################



#################  Register DNS  #############################
# create update_dns.sh
cat << REALEND > update_dns.sh
#!/bin/bash

DOMAIN=$DOMAIN
DNS_SERVER=$DNS_SERVER
ETH=$ETH
CIDR=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1 | sed 's/\.[0-9]*$/\.*/g' | head -n 1)


# Get the current private IP address
PRIVATE_IP=\$(ip addr show dev \$ETH | grep "inet " | awk '{print \$2}' | cut -d '/' -f 1)

# Get the current hostname
HOSTNAME=\$(hostname -s)

# Check if the private IP address is within the subnet
if [[ "\$PRIVATE_IP" == \$CIDR ]]; then
  # Get the current DNS record for the hostname
  CURRENT_IP=\$(dig +short -x \$PRIVATE_IP @\$DNS_SERVER | awk -F '.' '{print \$1"."\$2"."\$3"."\$4}')

  # Compare the current private IP address with the DNS record
  if [ "\$PRIVATE_IP" != "\$CURRENT_IP" ]; then
    # Update the DNS record
    echo "Updating DNS record for \$HOSTNAME.\$DOMAIN"
    nsupdate << EOF
    server \$DNS_SERVER
    update delete \$HOSTNAME.\$DOMAIN A
    update add \$HOSTNAME.\$DOMAIN 3600 A \$PRIVATE_IP
    send
EOF
  else
    echo "DNS record for \$HOSTNAME.\$DOMAIN is up to date"
  fi
else
  echo "Private IP address is not within the subnet"
fi
REALEND
sudo mv update_dns.sh /usr/local/bin/update_dns.sh
##############################################################


################  Create Service   ###########################
# create update_dns.service
cat << EOF > update_dns.service
#!/bin/bash

[Unit]
After=network.target

[Service]
ExecStart=/usr/local/bin/update_dns.sh

[Install]
WantedBy=default.target
EOF
sudo mv update_dns.service /etc/systemd/system/update_dns.service
##############################################################


#################   Enable Service   #########################
sudo chmod 755 /usr/local/bin/update_dns.sh
sudo chmod 664 /etc/systemd/system/update_dns.service
sudo systemctl daemon-reload
sudo systemctl enable update_dns.service
sudo systemctl start update_dns.service
##############################################################
