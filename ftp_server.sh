#!/bin/bash
# This script will install vsftpd on this machine. It also creates a new test user - ftptest

# Start of user inputs
###############################################################################
#PASSIVEMODE="yes"
PASSIVEMODE="no"
PASSIVESTARTPORT=45000
PASSIVEENDPORT=45000
# This is the public ip of the server
SERVERIP=52.42.43.33
FIREWALL="yes"
#FIREWALL="no"
USER1=ftptest
PASSWORD1="redhat"
###############################################################################
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
listen=YES
listen_ipv6=NO
pam_service_name=vsftpd
userlist_enable=YES

# To use tcp_wrappers and /etc/hosts.allow and /etc/hosts.deny for IP/hostname access
tcp_wrappers=NO
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
chroot_local_user=YES
allow_writeable_chroot=YES
EOF

if [[ $PASSIVEMODE == "yes" ]]
then
# Enable passive mode
	echo "pasv_enable=YES" >> /etc/vsftpd/vsftpd.conf
	echo "pasv_max_port=$PASSIVEENDPORT" >> /etc/vsftpd/vsftpd.conf
	echo "pasv_min_port=$PASSIVESTARTPORT" >> /etc/vsftpd/vsftpd.conf
	echo "# In case a server returns the internal IP on a PASV request" >> /etc/vsftpd/vsftpd.conf
	echo "pasv_address=$SERVERIP" >> /etc/vsftpd/vsftpd.conf
else
	echo "pasv_enable=NO" >> /etc/vsftpd/vsftpd.conf
fi


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
		if [[ $PASSIVEMODE == "yes" ]]
		then
			firewall-cmd --permanent --remove-port=$PASSIVESTARTPORT-$PASSIVEENDPORT/tcp
			firewall-cmd --permanent --add-port=$PASSIVESTARTPORT-$PASSIVEENDPORT/tcp
		fi
		firewall-cmd --reload
		echo "ftp added to firewall"
	else
		echo "firewalld not running"
		echo "No changes made to firewall"
	fi
fi

# Creating a file for testing
dd if=/dev/zero of=/home/ftptest/xxx bs=1024 count=10
echo `date` >> /home/ftptest/xxx
chmod 777 /home/ftptest/xxx

systemctl restart vsftpd
