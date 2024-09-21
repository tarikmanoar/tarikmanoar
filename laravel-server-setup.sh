#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m'

# Function to update and upgrade system
update_system() {
    echo -e "${GREEN}Updating and upgrading the system...${NC}"
    sudo apt update -y && sudo apt upgrade -y
}

# Function to install NGINX
install_nginx() {
    echo -e "${GREEN}Installing NGINX...${NC}"
    sudo apt install nginx -y
    sudo systemctl start nginx
    sudo systemctl enable nginx
}

# Function to install Apache
install_apache() {
    echo -e "${GREEN}Installing Apache...${NC}"
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo systemctl enable apache2
}

# Function to install PHP
install_php() {
    echo -e "${GREEN}Which PHP version do you want to install? (e.g., 8.0, 8.1, 7.4): ${NC}"
    read php_version

    echo -e "${GREEN}Installing PHP $php_version...${NC}"
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update
    sudo apt install php$php_version php$php_version-fpm php$php_version-mysql php$php_version-mbstring php$php_version-xml php$php_version-bcmath php$php_version-json php$php_version-zip -y
    sudo systemctl restart php$php_version-fpm
}

# Function to install MySQL
install_mysql() {
    echo -e "${GREEN}Installing MySQL...${NC}"
    sudo apt install mysql-server -y
    sudo systemctl start mysql
    sudo systemctl enable mysql

    echo -e "${GREEN}Securing MySQL installation...${NC}"
    sudo mysql_secure_installation
}

# Function to setup Laravel directory
setup_laravel() {
    echo -e "${GREEN}Setting up Laravel directory...${NC}"
    echo -e "${GREEN}Enter your project directory name: ${NC}"
    read project_name

    # Navigate to /var/www
    cd /var/www
    sudo mkdir $project_name
    cd $project_name

    # Clone Laravel project (you can customize this to use an existing project)
    sudo git clone https://github.com/your-repository.git .
    
    # Set permissions
    sudo chown -R www-data:www-data /var/www/$project_name
    sudo chmod -R 755 /var/www/$project_name

    # Install Composer
    sudo curl -sS https://getcomposer.org/installer | sudo php
    sudo mv composer.phar /usr/local/bin/composer
    composer install

    # Set up .env
    cp .env.example .env
    php artisan key:generate
}
# Function to get the server's public IP
get_public_ip() {
    PUBLIC_IP=$(curl -s ifconfig.me)
    echo $PUBLIC_IP
}

# Ask for domain or IP and use it
get_domain_or_ip() {
    echo -e "${GREEN}Enter your domain name (or leave blank to use the server's public IP): ${NC}"
    read domain_or_ip

    if [ -z "$domain_or_ip" ]; then
        domain_or_ip=$(get_public_ip)
        echo -e "${GREEN}No domain provided. Using server public IP: $domain_or_ip${NC}"
    else
        echo -e "${GREEN}Using provided domain: $domain_or_ip${NC}"
    fi
}

# Function to configure NGINX for Laravel
configure_nginx_laravel() {
    echo -e "${GREEN}Configuring NGINX for Laravel...${NC}"

    # Ask for domain or IP
    get_domain_or_ip

    # Create NGINX config file for Laravel
    sudo cat > /etc/nginx/sites-available/laravel <<EOL
server {
    listen 80;
    server_name $domain_or_ip;
    root /var/www/$project_name/public;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$php_version-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

    sudo ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx
}

# Function to configure Apache for Laravel
configure_apache_laravel() {
    echo -e "${GREEN}Configuring Apache for Laravel...${NC}"

    # Ask for domain or IP
    get_domain_or_ip

    # Create Apache config file for Laravel
    sudo cat > /etc/apache2/sites-available/laravel.conf <<EOL
<VirtualHost *:80>
    ServerName $domain_or_ip
    DocumentRoot /var/www/$project_name/public

    <Directory /var/www/$project_name>
        AllowOverride All
        Require all granted
    </Directory>

    <Directory /var/www/$project_name/public>
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php$php_version-fpm.sock|fcgi://localhost/"
    </FilesMatch>
</VirtualHost>
EOL

    sudo a2ensite laravel.conf
    sudo a2enmod rewrite
    sudo systemctl restart apache2
}


# Welcome message
echo -e "${GREEN}Welcome to the Laravel Server Setup Script${NC}"

# Update system
update_system

# Choose web server
echo -e "${GREEN}Choose your web server: ${NC}"
echo "1) NGINX"
echo "2) Apache"
read webserver

if [ "$webserver" == "1" ]; then
    install_nginx
    configure_nginx_laravel
elif [ "$webserver" == "2" ]; then
    install_apache
    configure_apache_laravel
else
    echo "Invalid choice!"
    exit 1
fi

# Install PHP
install_php

# Install MySQL
echo -e "${GREEN}Do you want to install MySQL? (y/n): ${NC}"
read install_mysql_choice

if [ "$install_mysql_choice" == "y" ]; then
    install_mysql
fi

# Set up Laravel
setup_laravel

echo -e "${GREEN}Laravel setup is complete!${NC}"
