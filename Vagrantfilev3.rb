# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  config.vbguest.auto_update = false
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_version = "20241002.0.0"
  # config.vbguest.auto_update = true
  # config.vbguest.iso_path = "http://download.virtualbox.org/virtualbox/7.1.6/VBoxGuestAdditions_7.1.6.iso"
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 22, host: 2224

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 22, host: 2223, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "192.168.56.10"

  # Create a public network, which generally matches a bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder "G:\\scripts\\shellscripts", "/opt/scripts"

  # Disable the default share of the current code directory. Doing this
  # provides improved isolation between the vagrant box and your host
  # by making sure your Vagrantfile isn't accessible to the vagrant box.
  # If you use this you may want to enable additional shared subfolders as
  # shown above.
  # config.vm.synced_folder ".", "/vagrant", disabled: true

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider "virtualbox" do |vb|
    #   # Display the VirtualBox GUI when booting the machine
    #   vb.gui = true
    #
    #   # Customize the amount of memory on the VM:
    vb.memory = "2048"
    vb.cpus = "2"
  end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: <<-'SHELL'
    # Configure Netplan
    sudo tee /etc/netplan/50-vagrant.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: yes
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

    # Update
    apt-get update
    apt-get upgrade -y
    apt-get install -y openvswitch-switch apache2 libapache2-mod-php mysql-server php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip

    # Disable Cloud-Init for network management
    echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

    # Create the directory if it doesn't exist
    sudo mkdir -p /etc/apache2/sites-available

    # Install and configure WordPress
    sudo tee /etc/apache2/sites-available/wordpress.conf <<EOF
<VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /srv/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF

    # Fix Netplan file permissions
    chmod 644 /etc/netplan/50-vagrant.yaml
    sleep 2 && netplan apply

    # Install Apache
    sudo mkdir -p /srv/www
    sudo chown www-data: /srv/www
    curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www

    # Enable WordPress site
    sudo a2ensite wordpress
    sudo a2enmod rewrite
    sudo a2dissite 000-default
    sudo systemctl restart apache2

    # Enable Open vSwitch
    systemctl enable --now openvswitch-switch

    # Create database and user
    mysql -u root <<EOF
    CREATE DATABASE wordpress;
    CREATE USER wordpress@localhost IDENTIFIED BY 'wordpress';
    GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER ON wordpress.* TO wordpress@localhost;
    FLUSH PRIVILEGES;
EOF

    # Configure WordPress
    sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
    sudo -u www-data sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
    sudo -u www-data sed -i 's/username_here/wordpress/' /srv/www/wordpress/wp-config.php
    sudo -u www-data sed -i 's/password_here/wordpress/' /srv/www/wordpress/wp-config.php

    #!/bin/bash

    # Define paths
    CONFIG_FILE="/srv/www/wordpress/wp-config.php"
    TEMP_SALTS="/tmp/wp-keys.txt"

    # Check if the wp-config.php file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ wp-config.php file not found at $CONFIG_FILE"
        exit 1
    fi

    # Download new WordPress keys
    curl -s https://api.wordpress.org/secret-key/1.1/salt/ > "$TEMP_SALTS"
    if [ $? -ne 0 ]; then
        echo "❌ Error while downloading new keys."
        exit 1
    fi
    echo "✅ New keys downloaded:"
    cat "$TEMP_SALTS"

    # Remove old keys (taking into account extra spaces)
    sed -i "/define( *'AUTH_KEY'/d" "$CONFIG_FILE"
    sed -i "/define( *'SECURE_AUTH_KEY'/d" "$CONFIG_FILE"
    sed -i "/define( *'LOGGED_IN_KEY'/d" "$CONFIG_FILE"
    sed -i "/define( *'NONCE_KEY'/d" "$CONFIG_FILE"
    sed -i "/define( *'AUTH_SALT'/d" "$CONFIG_FILE"
    sed -i "/define( *'SECURE_AUTH_SALT'/d" "$CONFIG_FILE"
    sed -i "/define( *'LOGGED_IN_SALT'/d" "$CONFIG_FILE"
    sed -i "/define( *'NONCE_SALT'/d" "$CONFIG_FILE"

    echo "✅ Old keys removed."

    # Check if the line "That's all, stop editing! Happy publishing." exists
    if ! grep -q "/* That's all, stop editing! Happy publishing. */" "$CONFIG_FILE"; then
        echo "⚠️ The line '/* That's all, stop editing! Happy publishing. */' is missing in wp-config.php."
        echo "✅ Adding the missing line..."
        echo "/* That's all, stop editing! Happy publishing. */" >> "$CONFIG_FILE"
    fi

    # Create a modified temporary file
    awk -v salts="$TEMP_SALTS" '
    {
        print $0;
        if ($0 ~ /\/\* That'\''s all, stop editing! Happy publishing. \*\//) {
            while ((getline line < salts) > 0) {
                print line;
            }
        }
    }' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"

    # Replace the original file
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    chown www-data:www-data "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"

    # Cleanup
    rm -f "$TEMP_SALTS"

    echo "✅ Security keys update completed."

    # Verify added keys
    echo "✅ Verifying added keys:"
    grep "define( *'[A-Z_]*'," "$CONFIG_FILE"

    echo "✅ Security keys update completed."

    # Restart Apache
    sudo systemctl restart apache2



  SHELL
end