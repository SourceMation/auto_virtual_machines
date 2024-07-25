# Install the PostgreSQL packages
sudo dnf module install -y postgresql:15/server

# Initialize PostgreSQL database
postgresql-setup --initdb

# Start services
systemctl start postgresql.service
systemctl enable postgresql.service

# Stworzenie skryptu do zmiany hasła po pierwszym zalogowaniu
cat >> /opt/start_configuration.sh << EOF
if [ -t 0 ]; then
    while true; do
        read -p "Do You want to start first-time configuration of Your PostgreSQL? " yn
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
MY_USER=\$(whoami)
cd /
echo ""
echo ""
echo "+==============================================+"
echo "|Please enter new password for PostgreSQL admin|"
echo "+==============================================+"
read -p "Enter new password : " POSTGRESQL_PASS
COMMAND="ALTER USER postgres with encrypted password '\$POSTGRESQL_PASS';"
sudo -u postgres psql -d template1 -c "\$COMMAND"
echo ""
echo -n "Collecting informations about installed PostgreSQL . . ."
POSTGRESQL_DEFAULT_DATA_DIRECTORY_PATH=\$(sudo -u postgres psql -t -P format=unaligned  -c 'SHOW data_directory')
POSTGRESQL_DEFAULT_CONFIG_PATH=\$(sudo -u postgres psql -t -P format=unaligned  -c 'SHOW config_file')
POSTGRESQL_DEFAULT_HBA_PATH=\$(sudo -u postgres psql -t -P format=unaligned  -c 'SHOW hba_file')
POSTGRESQL_DEFAULT_LOG_PATH="\$POSTGRESQL_DEFAULT_DATA_DIRECTORY_PATH/\$(sudo -u postgres psql -t -P format=unaligned  -c 'SHOW log_directory')"

echo ""
echo "Default PostgreSQL settings:"
echo " data directory path: \$POSTGRESQL_DEFAULT_DATA_DIRECTORY_PATH"
echo " config_file path: \$POSTGRESQL_DEFAULT_CONFIG_PATH"
echo " hba_file path: \$POSTGRESQL_DEFAULT_HBA_PATH"
echo " logs path: \$POSTGRESQL_DEFAULT_LOG_PATH"
echo " admin username: postgres"
echo " admin password: \$POSTGRESQL_PASS"
echo ""
sudo sed -i 's|^local[[:blank:]]*all[[:blank:]]*all[[:blank:]]*peer$|local   all             all                                     md5|g' \$POSTGRESQL_DEFAULT_HBA_PATH
sudo systemctl restart postgresql.service

echo "Creates new role '\$MY_USER' for PostgreSQL database"
echo "This will allow You access postgres as a admin"
createuser -U postgres -W -d -r -e -P -E -l -s \$MY_USER
echo ""
echo ""
echo ""
echo "You can login to postgresql shell using:"
echo " psql <database_name>"
echo "To create Your own database execute following:"
echo " createdb DATABASE_NAME"
sudo sed -i "/start_configuration/d" /etc/bashrc
sudo rm -rf /opt/one_time_script.sh
sudo rm -rf /opt/start_configuration.sh
cd ~
EOF

chmod +x /opt/one_time_script.sh
chmod +x /opt/start_configuration.sh
echo ". /opt/start_configuration.sh" >> /etc/bashrc