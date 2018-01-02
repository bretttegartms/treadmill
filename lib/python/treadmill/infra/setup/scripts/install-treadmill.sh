#if [ ! -e /etc/yum.repos.d/treadmill.repo ]; then
#    curl -L https://s3.amazonaws.com/yum_repo_dev/treadmill.repo -o /etc/yum.repos.d/treadmill.repo
#fi

# Install S6, execline and pid1
yum install http://192.168.241.33/s6-2.6.2.0-1.el7.x86_64.rpm --nogpgcheck -y
yum install http://192.168.241.33/execline-2.3.0.4-1.el7.x86_64.rpm --nogpgcheck -y
yum install http://192.168.241.33/treadmill-pid1-1.0-3.x86_64.rpm --nogpgcheck -y

# Install treadmill
mkdir -p /opt/treadmill/bin
curl -L http://192.168.241.33/treadmill -o /opt/treadmill/bin/treadmill
chmod +x /opt/treadmill/bin/treadmill
