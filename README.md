# cloud-init-vSphere-image-prep-scripts


There are 4 scripts that you can execute on base CentOs/RHEL or Ubuntu to install cloud-init and configure the image template to work with vSphere customization with dhcp or ip static assigments

There are two files for each of the linux distro, the ones with a myblog at the end of the file name uses a cron job approach that I used in my blog below and the one without, uses a custom runonce service that we create instead of using a cron job. Both works but at the end these are two different aproaches , your welcome to use which ever one you prefer. 


**Note after you git clone the repo to your linux machine**

Make sure to Convert Windows-style line endings to Unix-style otherwise you will get an error like this when you try to execute the script :
"Bash script and /bin/bash^M: bad interpreter: No such file or directory [duplicate]"

Though there are some tools (e.g. dos2unix) available to convert between DOS/Windows (\r\n) and Unix (\n) line endings, you'd sometimes like to solve this rather simple task with tools available on any linux box you connect to. So, here are some examples -

sed -i -e 's/\r$//' scriptname.sh

This is based on my blog here https://vmwarelab.org/2020/02/14/vsphere-customization-with-cloud-init-while-using-vrealize-automation-8-or-cloud/
