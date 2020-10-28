# cloud-init-scripts

There are 4 scripts that you can execute on base CentOs/RHEL or Ubuntu to install cloud-init and configure the image to work with vSphere customization with dhcp or ip static assigments

There are two files for each of the linux distro, the one with a myblog at the end of the file name uses a cron job approach that I used and the one without uses a custom runonce service that we create instead of using a cron job. Both works but at the end these are two different aproaches , your welcome to use which ever one you prefer. 

This is based on my blog here https://vmwarelab.org/2020/02/14/vsphere-customization-with-cloud-init-while-using-vrealize-automation-8-or-cloud/
