# Configure the package management system
cat << EOF > /etc/yum.repos.d/mongodb-org-7.0.repo
[mongodb-org-8.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/8.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
EOF


# Install the MongoDB packages
dnf install -y mongodb-org
systemctl enable mongod
