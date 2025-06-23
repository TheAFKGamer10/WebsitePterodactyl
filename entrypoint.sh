#!/bin/bash
cd /home/container

# Make internal Docker IP address available to processes.
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# check if CMS is Joomla or Wordpress, if it is then disable, then check if the status is true or 1, if it is true or 1 then reun the ioncube install if not then continue
if [[ "$CMS" != "Joomla" && "$CMS" != "Wordpress" && "$IONCUBE_STATUS" =~ ^(true|1)$ ]]; then
    ARCH=$(uname -m)
    PHP_EXT_DIR=$(php -r "echo ini_get('extension_dir');")
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    if [ "$ARCH" = "x86_64" ]; then
        IONCUBE_ARCH="x86-64"
    elif [ "$ARCH" = "aarch64" ]; then
        IONCUBE_ARCH="aarch64"
    else
        echo "Unsupported architecture: $ARCH" >&2; exit 1
    fi
    cd /tmp
    wget -O ioncube.tar.gz "https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_${IONCUBE_ARCH}.tar.gz"
    tar xzf ioncube.tar.gz
    cp ioncube/ioncube_loader_lin_${PHP_VERSION}.so "$PHP_EXT_DIR"
    echo "zend_extension=${PHP_EXT_DIR}/ioncube_loader_lin_${PHP_VERSION}.so" > /etc/php/${PHP_VERSION}/cli/conf.d/00-ioncube.ini
    echo "zend_extension=${PHP_EXT_DIR}/ioncube_loader_lin_${PHP_VERSION}.so" > /etc/php/${PHP_VERSION}/fpm/conf.d/00-ioncube.ini
    rm -rf /tmp/ioncube*
fi

# Replace Startup Variables
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}
