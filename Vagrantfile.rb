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

  # Create a public network, which generally matched to bridged network.
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
config.vm.provision "shell", inline: <<-SHELL


  # Configurer Netplan
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
#mise à jour
  apt-get update
  apt-get upgrade
  apt-get install -y openvswitch-switch apache2 libapache2-mod-php mysql-server php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip
# Désactiver Cloud-Init pour la gestion du réseau
  echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

# Création du dossier s'il n'existe pas
  sudo mkdir -p /etc/apache2/sites-available
#Install and configure WordPress
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

  # Corriger les permissions du fichier Netplan
  chmod 644 /etc/netplan/50-vagrant.yaml
  sleep 2 && netplan apply

  # Appliquer Netplan après un petit délai pour éviter les conflits
  
  netplan apply

  # Installer Apache
  
  apt-get install -y 
  sudo mkdir -p /srv/www
  sudo chown www-data: /srv/www
  curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www
  
  #Enable the site with:
  sudo a2ensite wordpress
#Enable URL rewriting with:
  sudo a2enmod rewrite
#Disable the default “It Works” site with:
  sudo a2dissite 000-default
#sudo service apache2 reload
  sudo systemctl restart apache2
# activer Open cSwitch
  systemctl enable --now openvswitch-switch
  systemctl restart apache2
  systemctl reload apache2
# Création de la base de données et de l'utilisateur
  mysql -u root <<EOF
  CREATE DATABASE wordpress;
  CREATE USER wordpress@localhost IDENTIFIED BY 'wordpress';
  GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER ON wordpress.* TO wordpress@localhost;
  FLUSH PRIVILEGES;
EOF
  systemctl enable mysql
  systemctl start mysql
#First, copy the sample configuration file to wp-config.php
  sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
#Next, set the database credentials in the configuration file 
#(do not replace database_name_here or username_here in the commands below. 
#Do replace <your-password> with your database password.):
  sudo -u www-data sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
  sudo -u www-data sed -i 's/username_here/wordpress/' /srv/www/wordpress/wp-config.php
  sudo -u www-data sed -i 's/password_here/wordpress/' /srv/www/wordpress/wp-config.php

# Remplacement automatique des clés de sécurité dans wp-config.php
  sudo -u www-data bash -c 'curl -s https://api.wordpress.org/secret-key/1.1/salt/ > /tmp/wp-keys'

# suppression des clés dans wp-config.php
  sudo sed -i "/AUTH_KEY/d" /srv/www/wordpress/wp-config.php
  sudo sed -i "/SECURE_AUTH_KEY/d" /srv/www/wordpress/wp-config.php
  sudo sed -i "/LOGGED_IN_KEY/d" /srv/www/wordpress/wp-config.php
  sudo sed -i "/NONCE_KEY/d" /srv/www/wordpress/wp-config.php
  sudo sed -i "/AUTH_SALT/d" /srv/www/wordpress/wp-config.php
  sudo sed -i "/SECURE_AUTH_SALT/d" /srv/www/wordpress/wp-config.php
  sudo sed -i "/LOGGED_IN_SALT/d" /srv/www/wordpress/wp-config.php
  sudo sed -i "/NONCE_SALT/d" /srv/www/wordpress/wp-config.php

# Ajout des nouvelles clés
  sudo cat /tmp/wp-keys >> /srv/www/wordpress/wp-config.php
  sudo rm /tmp/wp-keys
# Activation du site et redémarrage d'Apache
  sudo a2ensite wordpress
  sudo a2enmod rewrite
  sudo systemctl restart apache2

SHELL

end
