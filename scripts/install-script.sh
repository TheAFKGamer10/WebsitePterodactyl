#!/bin/bash

# [SETUP] Install necessary packages, including git
echo -e "[SETUP] Install packages"
apt-get update && apt-get install -y git wget perl perl-doc fcgiwrap

# Change to server directory
cd /mnt/server

# [SETUP] Create necessary folders
echo -e "[SETUP] Create folders"
mkdir -p logs tmp www

# Clone the default repository into a temporary directory
echo "[Git] Cloning default repository."
git clone https://github.com/TheAFKGamer10/WebsitePterodactyl /mnt/server/gtemp >/dev/null 2>&1 && echo "[Git] Repository cloned successfully." || {
    echo "[Git] Error: Default repository clone failed."
    exit 21
}

# Copy the www folder and files from the temporary repository to the target directory
echo "[Git] Copying folder and files from default repository."
cp -r /mnt/server/gtemp/nginx /mnt/server || {
    echo "[Git] Error: Copying 'nginx' folder failed."
    exit 22
}
cp -r /mnt/server/gtemp/php /mnt/server || {
    echo "[Git] Error: Copying 'php' folder failed."
    exit 22
}
cp -r /mnt/server/gtemp/modules /mnt/server || {
    echo "[Git] Error: Copying 'modules' folder failed."
    exit 22
}
cp /mnt/server/gtemp/start-modules.sh /mnt/server || {
    echo "[Git] Error: Copying 'start-modules.sh' file failed."
    exit 22
}
cp /mnt/server/gtemp/LICENSE /mnt/server || {
    echo "[Git] Error: Copying 'LICENSE' file failed."
    exit 22
}
chmod +x /mnt/server/start-modules.sh
find /mnt/server/modules -type f -name "*.sh" -exec chmod +x {} \;

# Remove the temporary cloned repository
rm -rf /mnt/server/gtemp

# Check if GIT_ADDRESS is set
if [ -z "${GIT_ADDRESS}" ]; then
    echo "[Git] Info: GIT_ADDRESS is not set."
    echo "[Git] Git operations are disabled. Skipping Git actions."
else
    # Add .git suffix to GIT_ADDRESS if it's not present
    if [[ ${GIT_ADDRESS} != *.git ]]; then
        GIT_ADDRESS="${GIT_ADDRESS}.git"
        echo "[Git] Added .git suffix to GIT_ADDRESS: ${GIT_ADDRESS}"
    fi

    # If username and access token are provided, use authenticated access
    if [ -n "${USERNAME}" ] && [ -n "${ACCESS_TOKEN}" ]; then
        echo "[Git] Using authenticated Git access."

        # Extract the domain and the rest of the URL, ensuring the correct format
        GIT_DOMAIN=$(echo "${GIT_ADDRESS}" | cut -d/ -f3)
        GIT_REPO=$(echo "${GIT_ADDRESS}" | cut -d/ -f4-) # Rest of the URL after the domain

        # Construct the authenticated Git URL
        GIT_ADDRESS="https://${USERNAME}:${ACCESS_TOKEN}@${GIT_DOMAIN}/${GIT_REPO}"

        echo "[Git] Updated GIT_ADDRESS for authenticated access: ${GIT_ADDRESS}"
    else
        echo "[Git] Using anonymous Git access."
    fi

    # Check if the 'www' directory exists, if not create it
    if [ ! -d /mnt/server/www ]; then
        echo "[Git] Creating /mnt/server/www directory."
        mkdir -p /mnt/server/www
    else
        rm -R /mnt/server/www && mkdir -p /mnt/server/www
    fi

    cd /mnt/server/www || {
        echo "[Git] Error: Could not access /mnt/server/www directory."
        exit 1
    }

    if [ "$(ls -A /mnt/server/www)" ]; then
        echo "[Git] /mnt/server/www directory is not empty."

        # Check if .git directory exists in 'www'
        if [ -d .git ]; then
            echo "[Git] .git directory exists in 'www'."

            # Check if .git/config exists in 'www'
            if [ -f .git/config ]; then
                echo "[Git] Loading repository info from git config in 'www'."
                ORIGIN=$(git config --get remote.origin.url)
            else
                echo "[Git] Error: .git/config not found in 'www'. The directory may contain files, but it's not a valid Git repository."
                exit 10
            fi
        else
            echo "[Git] Error: Directory contains files but no Git repository found in 'www'."
            exit 11
        fi

        # Check if origin matches the provided GIT_ADDRESS
        if [ "${ORIGIN}" == "${GIT_ADDRESS}" ]; then
            echo "[Git] Repository origin matches. Pulling latest changes from ${GIT_ADDRESS} in 'www'."
            git pull || {
                echo "[Git] Error: git pull failed for 'www'."
                exit 12
            }
        else
            echo "[Git] Error: Repository origin does not match the provided GIT_ADDRESS in 'www'."
            exit 13
        fi
    else
        # The directory is empty, clone the repository
        echo "[Git] /mnt/server/www directory is empty. Cloning ${GIT_ADDRESS} into /mnt/server/www."
        git clone ${GIT_ADDRESS} . >/dev/null 2>&1 && echo "[Git] Repository cloned successfully." || {
            echo "[Git] Error: git clone failed for 'www'."
            exit 14
        }
    fi
fi

function wordpress() {
    echo "[SETUP] Install WordPress"
    cd /mnt/server/www
    wget -q http://wordpress.org/latest.tar.gz >/dev/null 2>&1 || {
        echo "[SETUP] Error: Downloading WordPress failed."
        exit 16
    }
    tar xzf latest.tar.gz >/dev/null 2>&1
    mv wordpress/* .
    rm -rf wordpress latest.tar.gz
    echo "[SETUP] WordPress installed - http://<ip>:<port>/wp-admin"
}
function joomla() {
    echo "[SETUP] Install Joomla"
    cd /mnt/server/www

    # Determine version and major version
    if [ -z "$VERSION" ]; then
        version=$(curl -s https://downloads.joomla.org/api/v1/latest/cms | jq -r '.branches[-1].version')
        version_major=$(echo "$version" | cut -d '.' -f 1)
    else
        version="$VERSION"
        version_major="${MAJOR_VERSION:-$(echo "$VERSION" | cut -d '.' -f 1)}"
    fi

    version_hyphenated=$(echo "$version" | tr '.' '-')
    joomla_url="https://downloads.joomla.org/cms/joomla${version_major}/${version_hyphenated}/Joomla_${version_hyphenated}-Stable-Full_Package.tar.gz"

    wget -q "$joomla_url" -O joomla.tar.gz || {
        echo "[SETUP] Error: Downloading Joomla failed."
        exit 16
    }
    tar -xzf joomla.tar.gz -C . || {
        echo "[SETUP] Error: Unzipping Joomla failed."
        exit 18
    }
    rm -f joomla.tar.gz
    echo "[SETUP] Joomla installed - http://<ip>:<port>/administrator"
}

# Check if WordPress should be installed
if [ "${CMS}" == "Wordpress" ]; then
    wordpress
elif [ "${CMS}" == "Joomla" ]; then
    joomla
else
    echo "[SETUP] No CMS specified. Skipping CMS installation."
fi

echo -e "[DONE] Everything has been installed successfully"
echo -e "[INFO] You can now start the nginx web server"
