# COPY rabbitmq.repo - Create all necessary files

tee /etc/yum.repos.d/rabbitmq.repo > /dev/null <<EOT
[rabbitmq]
name = RabbitMQ repository
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/9/x86_64/RabbitMQ/os/
enabled=1
gpgcheck=0
skip_if_unavailable=True
sslverify=0
EOT

dnf install -y rabbitmq-server-3.*
systemctl enable rabbitmq-server
