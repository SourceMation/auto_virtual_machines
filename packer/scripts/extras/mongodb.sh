# Configure the package management system
cat << EOF > /etc/yum.repos.d/mongodb-org-7.0.repo
[mongodb-enterprise-7.0]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/redhat/\$releasever/mongodb-enterprise/7.0/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
EOF

# Install the MongoDB packages
dnf install -y mongodb-enterprise-7.0.4

systemctl start mongod
systemctl enable mongod

MONGODB_DEFAULT_USERNAME="admin"
MONGODB_DEFAULT_PASSWORD="admin"

echo "vm.max_map_count=9999999" | sudo tee -a /etc/sysctl.conf

cat >> /etc/systemd/system/disable-transparent-huge-pages.service << EOF
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'

[Install]
WantedBy=basic.target
EOF

systemctl daemon-reload
systemctl start disable-transparent-huge-pages
systemctl enable disable-transparent-huge-pages

# Stworzenie skryptu do zmiany hasła po pierwszym zalogowaniu
cat >> /opt/start_configuration.sh << EOF
if [ -t 0 ]; then
    while true; do
        read -p "Do You want to start first-time configuration of Your MongoDB? " yn
        case \$yn in
            [Yy]* ) . /opt/one_time_script.sh; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi
EOF

cat >> /opt/one_time_script.sh << EOF
#!/bin/bash
echo ""
echo ""
echo -n "Collecting informations about installed MongoDB . . ."
MONGODB_DEFAULT_CONFIG_PATH=\$(mongosh --quiet --eval "db.serverCmdLineOpts().parsed.config" admin)
MONGODB_DEFAULT_DB_PATH=\$(mongosh --quiet --eval "db.serverCmdLineOpts().parsed.storage.dbPath" admin)
MONGODB_DEFAULT_LOG_PATH=\$(mongosh --quiet --eval "db.serverCmdLineOpts().parsed.systemLog.path" admin)
mongosh --quiet --eval "db.createUser({user: \"$MONGODB_DEFAULT_USERNAME\", pwd: \"$MONGODB_DEFAULT_PASSWORD\", roles: [{ role: \"root\", db: \"admin\" }]})" admin
if [ "\$EUID" != "0" ]; then
    sudo sed -iE "s|#security:|security:\n  authorization: enabled|g" \$MONGODB_DEFAULT_CONFIG_PATH
    sudo systemctl restart mongod
else
    sed -iE "s|#security:|security:\n  authorization: enabled|g" \$MONGODB_DEFAULT_CONFIG_PATH
    systemctl restart mongod
fi
echo ""
echo "Default MongoDB settings:"
echo " configfile path: \$MONGODB_DEFAULT_CONFIG_PATH"
echo " logs path: \$MONGODB_DEFAULT_LOG_PATH"
echo " database path: \$MONGODB_DEFAULT_DB_PATH"
echo " admin username: $MONGODB_DEFAULT_USERNAME"
echo " admin password: $MONGODB_DEFAULT_PASSWORD"
echo ""
echo "+============================================+"
echo "|Please change the default password for admin|"
echo "+============================================+"
sleep 4
mongosh --quiet -u $MONGODB_DEFAULT_USERNAME -p $MONGODB_DEFAULT_PASSWORD --eval "db.changeUserPassword(\"$MONGODB_DEFAULT_USERNAME\", passwordPrompt())" admin
echo ""
echo "You can login to mongodb shell using:"
echo " mongosh -u admin -p Your new password"
echo "OR"
echo " using following method inside mongodb shell"
echo " db.auth(\"admin\", \"Your new password\")"
echo ""
echo ""
if [ "\$EUID" != "0" ]; then
    sudo sed -i "/start_configuration/d" /etc/bashrc
    sudo rm -rf /opt/one_time_script.sh
    sudo rm -rf /opt/start_configuration.sh
else
    sed -i "/start_configuration/d" /etc/bashrc
    rm -rf /opt/one_time_script.sh
    rm -rf /opt/start_configuration.sh
fi
EOF

chmod +x /opt/one_time_script.sh
chmod +x /opt/start_configuration.sh
echo ". /opt/start_configuration.sh" >> /etc/bashrc