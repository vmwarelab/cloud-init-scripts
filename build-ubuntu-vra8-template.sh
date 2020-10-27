#!/bin/bash

###Create a runonce script for re-exec cloud-init. ###
###System Update###
sudo apt-get update && sudo apt-get -y upgrade
###install cloud-init. ### 
sudo apt-get -y install cloud-init

###install perl ### 
sudo apt-get -y install perl

###disable vmware customization for cloud-init. ###
sudo sed -i 's/^disable_root: true/disable_root: false/g' /etc/cloud/cloud.cfg
sudo sed -i '/^preserve_hostname: false/a\disable_vmware_customization: true' /etc/cloud/cloud.cfg


###setting datasouce is OVF only. ### 
sudo sed -i '/^disable_vmware_customization: true/a\datasource_list: [OVF]' /etc/cloud/cloud.cfg

###disable cloud-init config network. ###
sed -i '/^disable_vmware_customization: true/a\network:' /etc/cloud/cloud.cfg
sed -i '/^network:/a\  config: disabled' /etc/cloud/cloud.cfg

###disalbe clean tmp folder. ### 
sudo sed -i 's/D/#&/' /usr/lib/tmpfiles.d/tmp.conf

###Add After=dbus.service to open-vm-tools. ### 
sudo sed -i '/^After=vgauthd.service/a\After=dbus.service' /lib/systemd/system/open-vm-tools.service

###disable cloud-init in first boot,we use vmware tools exec customization. ### 
sudo touch /etc/cloud/cloud-init.disabled

cat <<EOF > /etc/cloud/runonce.sh
#!/bin/bash


  sudo rm -rf /etc/cloud/cloud-init.disabled
  sudo systemctl restart cloud-init.service
  sudo systemctl restart cloud-config.service
  sudo systemctl restart cloud-final.service
  sudo systemctl disable runonce
  sudo touch /tmp/cloud-init.success
EOF

###Create a runonce service for exec runonce.sh with system after reboot. ### 
cat <<EOF > /etc/systemd/system/runonce.service
[Unit]
Description=Run once
Requires=network-online.target
Requires=cloud-init-local.service
After=network-online.target
After=cloud-init-local.service

[Service]
###wait for vmware customization to complete, avoid executing cloud-init at the first startup.###
ExecStartPre=/bin/sleep 30
ExecStart=/etc/cloud/runonce.sh

[Install]
WantedBy=multi-user.target
EOF
###Create a cleanup script for build vra template. ### 
cat <<EOF > /etc/cloud/clean.sh
#!/bin/bash

#clear audit logs
if [ -f /var/log/audit/audit.log ]; then
cat /dev/null > /var/log/audit/audit.log
fi
if [ -f /var/log/wtmp ]; then
cat /dev/null > /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
cat /dev/null > /var/log/lastlog
fi

#cleanup persistent udev rules
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
rm /etc/udev/rules.d/70-persistent-net.rules
fi

#cleanup /tmp directories
rm -rf /tmp/*
rm -rf /var/tmp/*

#cleanup current ssh keys
#rm -f /etc/ssh/ssh_host_*

#cat /dev/null > /etc/hostname

#cleanup apt
#apt-get clean

#Clean Machine ID

truncate -s 0 /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

#Clean Cloud-init
cloud-init clean --logs --seed

#Disabled Cloud-init
touch /etc/cloud/cloud-init.disabled

#cleanup shell history
echo > ~/.bash_history
history -cw
EOF

###change script execution permissions. ### 
sudo chmod +x /etc/cloud/runonce.sh /etc/cloud/clean.sh

###reload runonce.service. ### 
sudo systemctl daemon-reload

###enable runonce.service on system boot. ### 
sudo systemctl enable runonce.service

###clean template. ### 
sudo /etc/cloud/clean.sh

###shutdown os. ###
shutdown -h now