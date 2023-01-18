#!/bin/bash

###System Update###
sudo yum update -y

###install cloud-init ### 
sudo yum install -y cloud-init

###install perl ### 
sudo yum install -y perl

#!/bin/bash

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
sudo sed -i 's/^disable_root: 1/disable_root: 0/g' /etc/cloud/cloud.cfg
sudo sed -i 's/^ssh_pwauth:   0/ssh_pwauth:   1/g' /etc/cloud/cloud.cfg

###disable vmware customization for cloud-init. ###
sudo sed -i 's/^disable_vmware_customization: false/disable_vmware_customization: true/g' /etc/cloud/cloud.cfg

###disable permanently disable SELinux on your CentOS system
sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config


###setting datasouce is OVF only. ### 
sudo sed -i '/^disable_vmware_customization: true/a\datasource_list: [OVF]' /etc/cloud/cloud.cfg

###disable cloud-init config network. ###
sudo sed -i '/^disable_vmware_customization: true/a\network:' /etc/cloud/cloud.cfg
sudo sed -i '/^network:/a\  config: disabled' /etc/cloud/cloud.cfg

###disalbe clean tmp folder. ### 
SOURCE_TEXT="v /tmp 1777 root root 10d"
DEST_TEXT="#v /tmp 1777 root root 10d"
sudo sed -i "s@${SOURCE_TEXT}@${DEST_TEXT}@g" /usr/lib/tmpfiles.d/tmp.conf
sudo sed -i "s/\(^.*10d.*$\)/#\1/" /usr/lib/tmpfiles.d/tmp.conf

###Add After=dbus.service to vmtoolsd. ### 
sudo sed -i '/^After=vgauthd.service/a\After=dbus.service' /usr/lib/systemd/system/vmtoolsd.service

###disable cloud-init in first boot,we use vmware tools exec customization. ### 
sudo touch /etc/cloud/cloud-init.disabled

###Create a runonce script for re-exec cloud-init. ###
cat <<EOF > /etc/cloud/runonce.sh
#!/bin/bash


sudo rm -rf /etc/cloud/cloud-init.disabled
sudo cloud-init init
sudo sleep 20
sudo cloud-init modules --mode config
sudo sleep 20
sudo cloud-init modules --mode final

sudo touch /tmp/cloud-init.complete

crontab -r

EOF

#Create a cron job
##crontab -l lists the current crontab jobs
##cat prints it 
##echo prints the new command
##crontab - adds all the printed stuff into the crontab file. 
##You can see the effect by doing a new crontab -l.

crontab -l | { cat; echo "@reboot ( sleep 90 ; sudo sh /etc/cloud/runonce.sh )"; } | crontab -
crontab -l

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
sudo rm /etc/udev/rules.d/70-persistent-net.rules
fi

#cleanup /tmp directories
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

#cleanup current ssh keys
#rm -f /etc/ssh/ssh_host_*

#cat /dev/null > /etc/hostname

#cleanup apt
sudo yum clean all

#Clean Machine ID

truncate -s 0 /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

#Clean Cloud-init
sudo cloud-init clean --logs --seed

#cleanup shell history
echo > ~/.bash_history
history -cw
EOF

###change script execution permissions. ### 
sudo chmod +x /etc/cloud/runonce.sh /etc/cloud/clean.sh

###clean template. ### 
sudo sh /etc/cloud/clean.sh

###shutdown os. ###
shutdown -h now
