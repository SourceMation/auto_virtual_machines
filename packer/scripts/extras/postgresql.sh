dnf module install -y postgresql:15/server
/usr/bin/postgresql-setup --initdb
systemctl enable postgresql
