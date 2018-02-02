MASTER_ID="{{ IDX }}"

yum install -y openldap-clients
source /etc/profile.d/treadmill_profile.sh

sudo mkdir -p /var/spool/tickets
sudo mkdir -p /var/spool/keytabs-proids
sudo chmod 777 /var/spool/tickets /var/spool/keytabs-proids

# force default back to FILE: from KEYRING:
cat <<%E%O%T | sudo su - root -c 'cat - >/etc/krb5.conf.d/default_ccache_name '
[libdefaults]
  default_ccache_name = FILE:/var/spool/tickets/%{username}
%E%O%T

kinit -k

(
TIMEOUT=30
retry_count=0
until ( ldapsearch -c -H $TREADMILL_LDAP ) || [ $retry_count -eq $TIMEOUT ]
do
    retry_count=$(($retry_count+1))
    sleep 30
done
)

ipa-getkeytab -r -p "${PROID}" -D "cn=Directory Manager" -w "{{ IPA_ADMIN_PASSWORD }}" -k /var/spool/keytabs-proids/"${PROID}".keytab
chown "${PROID}":"${PROID}" /var/spool/keytabs-proids/"${PROID}".keytab
su -c "kinit -k -t /var/spool/keytabs-proids/${PROID}.keytab ${PROID}" "${PROID}"

s6-setuidgid "${PROID}" \
    {{ TREADMILL }} admin ldap cell configure "{{ SUBNET_ID }}" --version 0.1 --root "{{ APP_ROOT }}" \
        --username "${PROID}" \
        --location local.local

s6-setuidgid "${PROID}" \
    {{ TREADMILL }} admin ldap cell insert "{{ SUBNET_ID }}" --idx "${MASTER_ID}" \
        --hostname "$(hostname -f)" --client-port 2181 --jmx-port 8989 --followers-port 2888 --election-port 3888

{{ TREADMILL }} --outfmt yaml admin ldap cell configure "{{ SUBNET_ID }}" > /var/tmp/cell_conf.yml

(
cat <<EOF
kinit -k -t /etc/krb5.keytab -c /var/spool/tickets/${PROID}
chown ${PROID}:${PROID} /var/spool/tickets/${PROID}
EOF
) > /etc/cron.hourly/hostkey-"${PROID}"-kinit

chmod 755 /etc/cron.hourly/hostkey-"${PROID}"-kinit
/etc/cron.hourly/hostkey-"${PROID}"-kinit

# Install master service
{{ TREADMILL }} admin install --install-dir /var/tmp/treadmill-master \
    --override "profile=cloud" \
    --config /var/tmp/cell_conf.yml master --master-id "${MASTER_ID}"

(
cat <<EOF
[Unit]
Description=Treadmill master services
After=network.target

[Service]
User=root
Group=root
SyslogIdentifier=treadmill
ExecStartPre=/bin/mount --make-rprivate /
ExecStart=/var/tmp/treadmill-master/treadmill/bin/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
) > /etc/systemd/system/treadmill-master.service


/bin/systemctl daemon-reload
/bin/systemctl enable treadmill-master.service --now
