#!/bin/bash
set -e

echo "Starting docker-entrypoint.sh..."

# Generate required locale
echo "Generating de_CH locale..."
locale-gen de_CH

# Create required directories
echo "Creating required directories..."
mkdir -p "users"
mkdir -p "spool"


echo "Checking for sql-ledger.conf..."
if [ ! -f ./sql-ledger.conf ]; then
    echo "sql-ledger.conf not found, creating default..."
    cp ./sql-ledger.conf.default ./sql-ledger.conf
fi

# Set up admin password and create members file
echo "Setting up admin password and creating members file..."
CRYPTED_PW=$(perl -e "print crypt '${RMA_ADMIN_PASSWORD:-secret}', 'root'")
CRYPTED_DB_PW=$(perl -e "print pack 'u', '${POSTGRES_PASSWORD}'")

echo "Creating members file with database configuration..."
cat > "./users/members" << EOF
# SQL-Ledger members configuration
# Defines database connection parameters and root login credentials

[root login]
password=${CRYPTED_PW}
dbdriver=Pg
dbhost=${POSTGRES_HOST}
dbname=${POSTGRES_DB}
dbuser=${POSTGRES_USER}
dbpasswd=${CRYPTED_DB_PW}
dbconnect=dbi:Pg:dbname=${POSTGRES_DB};host=${POSTGRES_HOST};port=5432

EOF
# [admin@${POSTGRES_DB}]
# charset=UTF8
# company=sql_ledger
# dateformat=mm-dd-yy
# dbconnect=dbi:Pg:dbname=${POSTGRES_DB};host=${POSTGRES_HOST};port=5432
# dbdriver=Pg
# dbhost=${POSTGRES_HOST}
# dbname=${POSTGRES_DB}
# dboptions=set DateStyle to 'POSTGRES, US';set client_encoding to 'UTF8'
# dbpasswd=${CRYPTED_DB_PW}
# dbport=5432
# dbuser=${POSTGRES_USER}
# name=Admin
# numberformat=1,000.00
# password=${CRYPTED_PW}
# templates=sql_ledger
# stylesheet=sql-ledger.css
# vclimit=1000

echo "Setting up Apache configuration..."
# Apache virtual host configuration
# Defines URL routing and security settings for the application

# Alias /${RMA_APP_NAME} ${RMA_INSTALLATION_PATH}
cat > /etc/apache2/conf-available/rma.conf << EOF
<VirtualHost *:80>
    ServerName localhost
    # ServerAlias *.localtest.me
    DocumentRoot ${RMA_INSTALLATION_PATH}

    LogLevel debug

    <Directory ${RMA_INSTALLATION_PATH}>
        AddHandler cgi-script .pl
        Options +ExecCGI +Includes +FollowSymlinks
        Require all granted
    </Directory>

    ProxyPreserveHost On

    <DirectoryMatch "^${RMA_INSTALLATION_PATH}/(users|bin|SL|sql|templates|locale)">
        Require all denied
    </DirectoryMatch>

    SetEnv PERL5LIB ${RMA_INSTALLATION_PATH}
</VirtualHost>
EOF

echo "Enabling Apache modules and configurations..."
a2enmod ssl cgid rewrite
a2enconf rma.conf
a2ensite default-ssl

echo "Setting proper permissions..."
chown -R www-data:www-data ./
chmod -R 755 ./
find ./ -name "*.pl" -exec chmod 755 {} \;

# Configure HTTPS redirect for enhanced security
if [ "${RMA_FORCE_HTTPS}" = "yes" ]; then
    echo "Configuring HTTPS redirect..."
    sed -i '/^<VirtualHost/a \
    RewriteEngine On\
    RewriteCond %{REQUEST_URI} ^/'"${RMA_APP_NAME}"'\
    RewriteRule .? https://%{SERVER_NAME}%{REQUEST_URI} [R=301,L]' /etc/apache2/sites-available/000-default.conf
fi

# Database availability check
echo "Waiting for PostgreSQL to be ready..."
tries=0
max_attempts=10
while [ $tries -lt $max_attempts ]; do
    if pg_isready -h db; then
        break
    fi
    echo "Database cluster on host db is not yet ready. Waiting..."
    sleep 5
    tries=$((tries + 1))
done

if [ $tries -eq $max_attempts ]; then
    echo "ERROR: Database cluster on host db not reachable after ${max_attempts} attempts"
    exit 1
fi

echo "docker-entrypoint.sh completed successfully"
exec "$@"
