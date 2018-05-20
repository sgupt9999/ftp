#!/bin/bash
# This script will install vsftpd on this machine
# Start of user inputs
#FIREWALL="yes"
FIREWALL="no"
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
fi

if yum list installed vsftpd > /dev/null 2>&1
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
yum install -y -q $INSTALLPACKAGES > /dev/null 2>&1
echo "Done"

systemctl start vsftpd
systemctl -q enable vsftpd

# Modify the ftp config file
sed -i 's/.*anonymous_enable.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*local_enable.*/local_enable=YES/' /etc/vsftpd/vsftpd.conf
sed -i 's/^write_enable.*/write_enable=YES/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*local_umask.*/local_mask=022/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*dirmessage_enable.*/dirmessage_enable=YES/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*xferlog_enable.*/xferlog_enable=YES/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*connect_from_port_20.*/connect_from_port_20=YES/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*xferlog_std_format.*/xferlog_std_format=YES/' /etc/vsftpd/vsftpd.conf
#sed -i 's/.*listen.*/listen=NO/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*listen_ipv6.*/listen_ipv6=YES/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*pam_service_name.*/pam_service_name=vsftpd/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*userlist_enable.*/userlist_enable=YES/' /etc/vsftpd/vsftpd.conf
sed -i 's/.*tcp_wrappers.*/tcp_wrappers=YES/' /etc/vsftpd/vsftpd.conf
echo "userlist_file=/etc/vsftpd.userlist" >> /etc/vsftpd/vsftpd.conf
echo "userlist_deny=NO" >> /etc/vsftpd/vsftpd.conf
echo "chroot_local_user=YES" >> /etc/vsftpd/vsftpd.conf
echo "allow_writable_chroot=YES" >> /etc/vsftpd/vsftpd.conf

setsebool -P ftpd_full_access=1

userdel -r -f $USER1
useradd $USER1
echo $PASSWORD1 | passwd --stdin $USER1
echo $USER1 > /etc/vsftpd.userlist
