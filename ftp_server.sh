#!/bin/bash
# This script will install vsftpd on this machine
# Start of user inputs
FIREWALL="yes"
#FIREWALL="no"
USER1=ftptest
PASSWORD1="redhat"
# End of user inputs



INSTALLPACKAGES="vsftpd"

if [[ $EUID != "0" ]]
then
	echo "ERROR. You need to have root privileges to run this script"
	exit 1
else
	echo "This script will install ftp server on this machine"
	echo "It will also create a test user ftptest"
fi

if yum list installed vsftpd
then
	systemctl -q is-active vsftpd && {
		systemctl stop vsftpd
		systemctl -q disable vsftpd
	}
	echo "Removing packages.........."
	yum remove vsftpd -y -q > /dev/null 2>&1
	echo "Done"
fi

echo "Installing $INSTALLPACKAGES.........."
yum install -y $INSTALLPACKAGES
echo "Done"

systemctl start vsftpd
systemctl enable vsftpd

# Modify the ftp config file
cat > /etc/vsftpd/vsftpd.conf << EOF
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
listen=NO
listen_ipv6=YES
pam_service_name=vsftpd
userlist_enable=YES
tcp_wrappers=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
chroot_local_user=YES
allow_writeable_chroot=YES
EOF

setsebool -P ftpd_full_access=1

userdel -r -f $USER1
useradd $USER1
echo $PASSWORD1 | passwd --stdin $USER1
echo $USER1 > /etc/vsftpd.userlist

if [[ $FIREWALL == "yes" ]]
then
	if systemctl -q is-active firewalld
	then
		firewall-cmd --permanent --add-service ftp
		firewall-cmd --reload
		echo "ftp added to firewall"
	else
		echo "firewalld not running"
		echo "No changes made to firewall"
	fi
fi

systemctl restart vsftpd
