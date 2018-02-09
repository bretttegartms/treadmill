yum -y install java-1.8.0-openjdk
yum -y install http://192.168.241.33/zookeeper-3.4.9-1.x86_64.rpm http://192.168.241.33/bigtop-utils-1.2.1-1.el7.centos.noarch.rpm http://192.168.241.33/zookeeper-ldap-plugin-0.1-0.x86_64.rpm --nogpgcheck 
echo "{{ CFG_DATA }}" >> /etc/zookeeper/conf/zoo.cfg

mac_addr=`cat /sys/class/net/eth0/address`
subnet_id=`curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/$mac_addr/subnet-id`
HOST_FQDN=$(hostname -f)

export TREADMILL_CELL=$subnet_id

mkdir /var/spool/keytabs-proids && chmod 755 /var/spool/keytabs-proids
mkdir /var/spool/keytabs-services && chmod 755 /var/spool/keytabs-services
mkdir /var/spool/tickets && chmod 755 /var/spool/tickets

# force default back to FILE: from KEYRING:
cat <<%E%O%T | sudo su - root -c 'cat - >/etc/krb5.conf.d/default_ccache_name '
[libdefaults]
  default_ccache_name = FILE:/var/spool/tickets/%{username}
%E%O%T

kinit -kt /etc/krb5.keytab

echo Retrieving Zookeeper service keytab
ipa-getkeytab -s "{{ IPA_SERVER_HOSTNAME }}" -p "zookeeper/$HOST_FQDN@{{ DOMAIN|upper }}" -k /var/spool/keytabs-services/zookeeper.keytab
chown "${PROID}":"${PROID}" /var/spool/keytabs-services/zookeeper.keytab

envsubst < /etc/zookeeper/conf/treadmill.conf > /etc/zookeeper/conf/temp.conf
mv /etc/zookeeper/conf/temp.conf /etc/zookeeper/conf/treadmill.conf -f
sed -i s/REALM/{{ DOMAIN|upper }}/g /etc/zookeeper/conf/treadmill.conf
sed -i s/PRINCIPAL/'"'zookeeper\\/$HOST_FQDN'"'/g /etc/zookeeper/conf/jaas.conf
sed -i s/KEYTAB/'"'\\/var\\/spool\\/keytabs-services\\/zookeeper.keytab'"'/g /etc/zookeeper/conf/jaas.conf

(
cat <<EOF
[Unit]
Description=Zookeeper distributed coordination server
After=network.target

[Service]
Type=forking
User=${PROID}
Group=${PROID}
SyslogIdentifier=zookeeper
Environment=ZOO_LOG_DIR=/var/lib/zookeeper
ExecStart=/usr/lib/zookeeper/bin/zkServer.sh start
ExecStop=/usr/lib/zookeeper/bin/zkServer.sh stop

[Install]
WantedBy=multi-user.target
EOF
) > /etc/systemd/system/zookeeper.service

chown -R "${PROID}":"${PROID}" /var/lib/zookeeper

su -c "zookeeper-server-initialize" "${PROID}"

su -c "echo {{ IDX }} > /var/lib/zookeeper/myid" "${PROID}"

kinit -k 

/bin/systemctl enable zookeeper.service
/bin/systemctl start zookeeper.service
