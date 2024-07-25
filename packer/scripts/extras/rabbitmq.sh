# COPY rabbitmq.repo - Create all necessary files
mkdir -p /etc/yum.repos.d/
tee /etc/yum.repos.d/rabbitmq.repo > /dev/null <<EOT
[rabbitmq]
name = RabbitMQ repository
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/9/x86_64/RabbitMQ/os/
enabled=1
gpgcheck=0
skip_if_unavailable=True
sslverify=0
EOT

ls -al /etc/yum.repos.d/rabbitmq.repo

# --------------------------------

export LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8
dnf install -y rabbitmq-server
set -eux
/usr/sbin/rabbitmq-plugins enable --offline rabbitmq_prometheus
/usr/sbin/rabbitmq-plugins enable --offline rabbitmq_management
export PATH=/usr/sbin:$PATH RABBITMQ_LOGS=-
export RABBITMQ_DATA_DIR=/var/lib/rabbitmq
# EXPOSE 4369 5671 5672 15691 15692 25672 15671 15672

echo "PATH=\"$PATH\"" >> /etc/bashrc
