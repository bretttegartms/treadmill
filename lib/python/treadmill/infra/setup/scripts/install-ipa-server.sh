# Global variables
IPA_DS_PASSWORD={{ IPA_ADMIN_PASSWORD }}
IPA_ADMIN_PASSWORD={{ IPA_ADMIN_PASSWORD }}
HOSTNAME=`hostname`

DOMAIN=`echo $HOSTNAME | sed 's/^[^.]*\.\(.*\)$/\1/'`
REALM=`echo $DOMAIN | tr '[[:lower:]]' '[[:upper:]]'`
sudo yum install -y ipa-server haveged ipa-server-dns bind-utils strace

sudo systemctl enable haveged
sudo systemctl start haveged

sudo systemctl stop chronyd
sudo systemctl disable chronyd

sudo systemctl enable ntpd
sudo systemctl start ntpd
sleep 3
peers=`sudo ntpq -c peers | tail -n +3 | wc -l`

touch /tmp/ipa-ready-for-install
PRIVATE_IP=`curl --silent http://169.254.169.254/latest/meta-data/local-ipv4`

mac=`curl --silent http://169.254.169.254/latest/meta-data/mac`

NETWORK=`curl --silent http://169.254.169.254/latest/meta-data/network/interfaces/macs/$mac/vpc-ipv4-cidr-block --write-out '\n'` 

grep -q "$PRIVATE_IP" /etc/hosts || echo "$PRIVATE_IP $HOSTNAME ipa" | sudo su - root -c 'cat - >>/etc/hosts'

# set BROADCAST environment variable
eval `ipcalc --broadcast $NETWORK`

dns_args=`awk -v network=$NETWORK -v broadcast=$BROADCAST '
BEGIN {
    split(network, a, "[. /]")

    ip  = lshift(a[1], 24) + lshift(a[2], 16) + lshift(a[3], 8) + a[4]
    mask = a[5]
    net = lshift(rshift(ip, 32 - mask), 32 - mask)

    split(broadcast, a, "[. /]")
    high_ip  = lshift(a[1], 24) + lshift(a[2], 16) + lshift(a[3], 8) + a[4]

    qty_net = (high_ip - ip + 1) / 256

    for (i = 0; i < qty_net; i++) {
        k = net + 256 * i
        printf("--reverse-zone=%d.%d.%d.in-addr.arpa ", and(rshift(k,  8), 0xff), and(rshift(k, 16), 0xff), and(rshift(k, 24), 0xff))

    }

    printf("--forwarder=%d.%d.%d.2\n", and(rshift(net, 24), 0xff), and(rshift(net, 16), 0xff), and(rshift(net, 8), 0xff))

    exit(0)
}'`
echo $dns_args>/tmp/dnsargs

if [ $peers -eq 0 -o -z "$IPA_DS_PASSWORD" -o -z "$IPA_ADMIN_PASSWORD" -o -z "$PRIVATE_IP" -o -z "$DOMAIN" -o -z "$REALM" -o -z "$HOSTNAME" -o -z "$dns_args" ]; then

    echo error missing data >/tmp/ipaservererror
    exit
fi

# force default back to FILE: from KEYRING:
cat <<%E%O%T | sudo su - root -c 'cat - >/etc/krb5.conf.d/default_ccache_name '
[libdefaults]
  default_ccache_name = FILE:/tmp/krb5cc_%{uid}
%E%O%T

touch /tmp/keyfile-setup


sudo ipa-server-install --verbose --unattended \
    --ds-password="$IPA_DS_PASSWORD" \
    --admin-password="$IPA_ADMIN_PASSWORD" \
    --ip-address "$PRIVATE_IP" \
    --hostname="$HOSTNAME" \
    --domain="$DOMAIN" \
    --realm="$REALM" \
    --no-host-dns \
    --setup-dns \
    --mkhomedir \
    --ssh-trust-dns \
    $dns_args


touch /tmp/ipa-installed

echo "$IPA_ADMIN_PASSWORD" | kinit admin

ipa dnszone-mod "$DOMAIN" --allow-sync-ptr=TRUE

#ipa dnsrecord-add "$DOMAIN" ipa-ca --a-rec $PRIVATE_IP

TMHOSTADM_OUTPUT=`ipa -n user-add tmhostadm --first tmhostadm --last proid --shell /bin/bash --class proid --random`

TMP_TMHOSTADM_PASSWORD=`echo "$TMHOSTADM_OUTPUT" | grep 'Random password:' | awk '{print $3}'`

NEW_TMHOSTADM_PASSWORD=`openssl rand -base64 12`

kpasswd tmhostadm <<!E!O!T
$TMP_TMHOSTADM_PASSWORD
$NEW_TMHOSTADM_PASSWORD
$NEW_TMHOSTADM_PASSWORD
!E!O!T

ipa role-add "Host Enroller" --desc "Host Enroller"
ipa role-add-privilege "Host Enroller" --privileges "Host Enrollment"
ipa role-add-privilege "Host Enroller" --privileges "Host Administrators"
ipa role-add-member "Host Enroller" --users tmhostadm

ipa role-add "Service Admin" --desc "Service Admin"
ipa role-add-privilege "Service Admin" --privileges "Service Administrators"
ipa role-add-member "Service Admin" --users tmhostadm

sudo kadmin.local -q "xst -norandkey -k /tmp/tmhostadm.keytab tmhostadm"
sudo chown tmhostadm:tmhostadm /tmp/tmhostadm.keytab

sudo su - root -c 'echo "su - tmhostadm -c \"kinit -k -t /tmp/tmhostadm.keytab tmhostadm\"" >/etc/cron.hourly/tmhostadm-kinit'

sudo chmod 755 /etc/cron.hourly/tmhostadm-kinit
sudo /etc/cron.hourly/tmhostadm-kinit

TREADMILL=/opt/treadmill/bin/treadmill

nohup sudo su - root -c "$TREADMILL sproc restapi -p 5108 --title 'Treadmill_API' -m ipa,cloud --cors-origin='.*' >/var/log/ipa_api.out 2>&1" &

# Outdated command? sproc restapi doesn't know what to do with the "tmhostadm" part
#nohup sudo su - root -c "$TREADMILL sproc restapi -p 5108 --title 'Treadmill_API' -m ipa,cloud --cors-origin='.*' tmhostadm >/var/log/ipa_api.out 2>&1" &

TREADMLD_OUTPUT=`ipa -n user-add --first=treadmld --last=proid --shell /bin/bash --class proid --random treadmld`

TMP_TREADMLD_PASSWORD=`echo "${TREADMLD_OUTPUT}" | grep 'Random password:' | awk '{print $3}'`

NEW_TREADMLD_PASSWORD=`openssl rand -base64 12`

kpasswd treadmld <<!E!O!T
$TMP_TREADMLD_PASSWORD
$NEW_TREADMLD_PASSWORD
$NEW_TREADMLD_PASSWORD
!E!O!T
