#!/bin/bash
############################################################################################
# This script will install vsftpd on this machine. It also creates a new test user - ftptest
############################################################################################

############################################################################################
# Start of user inputs
############################################################################################
#PASSIVEMODE="no" # If passive mode is not enabled and since the client sends a private IP 
		  # for data connection, only clients in the same network as the server 
		  # will be able to connetc
PASSIVEMODE="yes"
PASSIVESTARTPORT=45000
PASSIVEENDPORT=45000
SERVERIP=18.191.215.133 #This is the public ip of the server
FIREWALL="yes"
#FIREWALL="no"
LIMITACCESS="yes" # Limit access to the following user
USER1=ftptest
PASSWORD1="redhat123456"
############################################################################################
# End of user inputs
############################################################################################



INSTALLPACKAGES="vsftpd"

if [[ $EUID != "0" ]]
then
	echo 
	echo "##########################################################"
	echo "ERROR. You need to have root privileges to run this script"
	echo "##########################################################"
	exit 1
else
	echo
	echo "####################################################################"
	echo "This script will install ftp server on this machine"
	echo "If limited access requested, it will also create a test user ftptest"
	echo "####################################################################"
fi

if yum list installed vsftpd > /dev/null 2>&1
then
	systemctl -q is-active vsftpd && {
		systemctl stop vsftpd
		systemctl -q disable vsftpd
	}
	echo
	echo "###########################"
	echo "Removing old copy of vsftpd"
	yum remove vsftpd -y -q > /dev/null 2>&1
	echo "Done"
	echo "###########################"
fi

echo
echo "#################"
echo "Installing $INSTALLPACKAGES"
yum install -y -q $INSTALLPACKAGES > /dev/null 2>&1
echo "Done"
echo "##################"

systemctl -q enable --now vsftpd

# Modify the ftp config file
cat > /etc/vsftpd/vsftpd.conf << EOF
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
# To use tcp_wrappers and /etc/hosts.allow and /etc/hosts.deny for IP/hostname access
tcp_wrappers=NO
chroot_local_user=YES
allow_writeable_chroot=YES
EOF

if [[ $LIMITACCESS = "yes" ]]
then
	# remove anonymous access and grnt access to the new user
	echo "anonymous_enable=NO" >> /etc/vsftpd/vsftpd.conf
	echo "userlist_enable=YES" >> /etc/vsftpd/vsftpd.conf
	echo "userlist_deny=NO" >> /etc/vsftpd/vsftpd.conf
	echo "userlist_file=/etc/vsftpd/userlist" >> /etc/vsftpd/vsftpd.conf

	userdel -r -f $USER1 > /dev/null 2>&1
	useradd $USER1 > /dev/null 2>&1
	echo $PASSWORD1 | passwd --stdin $USER1 > /dev/null 2>&1
	rm -rf /etc/vsftpd/userlist 
	echo $USER1 > /etc/vsftpd/userlist
	
	# Creating a file for testing
	echo `date` >> /home/$USER1/testfile
	#chmod 777 /home/$USER1/testfile
else
	echo "anonymous_enable=YES" >> /etc/vsftpd/vsftpd.conf
fi	

if [[ $PASSIVEMODE == "yes" ]]
then
# Enable passive mode, add the port range on the server which can be added to the firewall
	echo "pasv_enable=YES" >> /etc/vsftpd/vsftpd.conf
	echo "pasv_max_port=$PASSIVEENDPORT" >> /etc/vsftpd/vsftpd.conf
	echo "pasv_min_port=$PASSIVESTARTPORT" >> /etc/vsftpd/vsftpd.conf
	echo "# In case a server returns the internal IP on a PASV request, then clients outsdie the network cannot connect " >> /etc/vsftpd/vsftpd.conf
	echo "pasv_address=$SERVERIP" >> /etc/vsftpd/vsftpd.conf
else
	echo "pasv_enable=NO" >> /etc/vsftpd/vsftpd.conf
fi


setsebool -P ftpd_full_access=1

if [[ $FIREWALL == "yes" ]]
then
	if systemctl -q is-active firewalld
	then
		echo
		echo "################################################"
		echo "Adding ftp and any passive ports to the firewall"
		firewall-cmd -q --permanent --add-service ftp
		if [[ $PASSIVEMODE == "yes" ]]
		then
			firewall-cmd -q --permanent --remove-port=$PASSIVESTARTPORT-$PASSIVEENDPORT/tcp
			firewall-cmd -q --permanent --add-port=$PASSIVESTARTPORT-$PASSIVEENDPORT/tcp
		fi
		firewall-cmd -q --reload
		echo "ftp added to firewall"
		echo "################################################"
	else
		echo
		echo "###########################"
		echo "firewalld not running"
		echo "No changes made to firewall"
		echo "###########################"
	fi
fi

systemctl restart vsftpd
echo
echo "###########################################"
echo "VSFTPD installation complete"
if [[ $PASSIVEMODE == "yes" ]]
then
	echo "FTP server configured in passive mode."
	echo "Please connect using the server public IP."
else
	echo "FTP server configured in active mode."
	echo "Please connect using the server private IP."
	echo "The access will only work from the"
	echo "machines on the same network as the server."
fi
if [[ $LIMITACCESS == "yes" ]]
then
	echo "Access is limited to user $USER1."
fi
echo "###########################################"

