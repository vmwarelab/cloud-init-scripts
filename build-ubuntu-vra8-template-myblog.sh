#!/bin/bash

###Create a runonce script for re-exec cloud-init. ###
###System Update###
sudo apt-get update && sudo apt-get -y upgrade
###install cloud-init. ### 
sudo apt-get -y install cloud-init

###install perl ### 
sudo apt-get -y install perl

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
###disable vmware customization for cloud-init. ###
sudo sed -i 's/^disable_root: true/disable_root: false/g' /etc/cloud/cloud.cfg
sudo sed -i '/^preserve_hostname: false/a\disable_vmware_customization: true' /etc/cloud/cloud.cfg


###setting datasouce is OVF only. ### 
sudo sed -i '/^disable_vmware_customization: true/a\datasource_list: [OVF]' /etc/cloud/cloud.cfg

###disable cloud-init config network. ###
sudo sed -i '/^disable_vmware_customization: true/a\network:' /etc/cloud/cloud.cfg
sudo sed -i '/^network:/a\  config: disabled' /etc/cloud/cloud.cfg

###disalbe clean tmp folder. ### 
sudo sed -i 's/D/#&/' /usr/lib/tmpfiles.d/tmp.conf

###Add After=dbus.service to open-vm-tools  ### 
sudo sed -i '/^After=vgauth.service/a\After=dbus.service' /lib/systemd/system/open-vm-tools.service

###disable cloud-init in first boot,we use vmware tools exec customization. ### 
sudo touch /etc/cloud/cloud-init.disabled

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

###clean template. ### 
sudo sh /etc/cloud/clean.sh

###shutdown os. ###
sudo shutdown -h now
