#!/bin/bash
###install cloud-init. ### 
yum install -y cloud-init

###install perl ### 
yum install -y perl

###System Update###
yum update -y

# Add any usernames you want to add to /etc/sudoers for passwordless sudo
users=("cloudadmin")

for user in "${users[@]}"
do
cat /etc/sudoers | grep ^$user
RC=$?
if [ $RC != 0 ]; then
bash -c "echo \"$user ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers"
fi
done


###eanble root and password login for ssh. ###
sed -i 's/^disable_root: 1/disable_root: 0/g' /etc/cloud/cloud.cfg
sed -i 's/^ssh_pwauth:   0/ssh_pwauth:   1/g' /etc/cloud/cloud.cfg

###disable vmware customization for cloud-init. ###
sed -i 's/^disable_vmware_customization: false/disable_vmware_customization: true/g' /etc/cloud/cloud.cfg

###setting datasouce is OVF only. ### 
sed -i '/^disable_vmware_customization: true/a\datasource_list: [OVF]' /etc/cloud/cloud.cfg


###disable cloud-init config network. ###
sed -i '/^disable_vmware_customization: true/a\network:' /etc/cloud/cloud.cfg
sed -i '/^network:/a\  config: disabled' /etc/cloud/cloud.cfg


###disable permanently disable SELinux on your CentOS system
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config


###disalbe clean tmp folder. ### 
SOURCE_TEXT="v /tmp 1777 root root 10d"
DEST_TEXT="#v /tmp 1777 root root 10d"
sed -i "s@${SOURCE_TEXT}@${DEST_TEXT}@g" /usr/lib/tmpfiles.d/tmp.conf
sed -i "s/\(^.*10d.*$\)/#\1/" /usr/lib/tmpfiles.d/tmp.conf

###Add After=dbus.service to vmtoolsd. ### 
sed -i '/^After=vgauthd.service/a\After=dbus.service' /usr/lib/systemd/system/vmtoolsd.service

###disable cloud-init in first boot,we use vmware tools exec customization. ### 
touch /etc/cloud/cloud-init.disabled

###Create a runonce script for re-exec cloud-init. ###
cat <<EOF > /etc/cloud/runonce.sh
#!/bin/bash


  rm -rf /etc/cloud/cloud-init.disabled
  sudo systemctl restart cloud-init.service
  sudo systemctl restart cloud-config.service
  sudo systemctl restart cloud-final.service
  sudo systemctl disable runonce
  touch /tmp/cloud-init.complete

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
yum clean all

#Clean Machine ID

truncate -s 0 /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

#Clean Cloud-init
cloud-init clean --logs --seed

#Disabled Cloud-init
touch /etc/cloud/cloud-init.disabled
systemctl enable runonce

#cleanup shell history
echo > ~/.bash_history
history -cw
EOF

###change script execution permissions. ### 
chmod +x /etc/cloud/runonce.sh /etc/cloud/clean.sh

###reload runonce.service. ### 
systemctl daemon-reload

###enable runonce.service on system boot. ### 
systemctl enable runonce.service

###clean template. ### 
/etc/cloud/clean.sh

###shutdown os. ###
shutdown -h now
