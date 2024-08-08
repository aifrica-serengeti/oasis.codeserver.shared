#!/bin/bash
echo "Starting script..."
USERNAME=${USER_NAME:-"사용자"}
PORT=${PORT:-65535}
INIT_MARKER=/home/coder/.initialized

# Check if the initialization marker file exists
if [ ! -f "$INIT_MARKER" ]; then
    echo "Initializing for the first time..."
    
    # Copy the contents of /coder to /home/coder
    sudo rsync -av /coder/ /home/coder/
    sudo chown -R coder:coder /home/coder/
    echo "Copied initial files to /home/coder."

    # Copy config.json to /home/coder/.continue/config.json
    if [ -f /config.json ]; then
        sudo mkdir -p /home/coder/.continue
        sudo cp /config.json /home/coder/.continue/config.json
        sudo chown coder:coder /home/coder/.continue/config.json
        echo "Copied /config.json to /home/coder/.continue/config.json."
    else
        echo "/config.json not found. Skipping copy."
    fi
    
    sudo touch $INIT_MARKER
    echo "Initialization complete."
fi

# Configure Git
    if [ -n "$USER_EMAIL" ]; then
        git config --global user.email "$USER_EMAIL"
        echo "Git user email set to $USER_EMAIL."
    fi
    
    if [ -n "$USER_NAME" ]; then
        git config --global user.name "$USER_NAME"
        echo "Git user name set to $USER_NAME."
    fi
    
    if [ -n "$GITLAB_TOKEN" ]; then
        git config --global credential.helper store
        git_credentials_path="/home/coder/.git-credentials"
        echo "https://oauth2:$GITLAB_TOKEN@gitlab.codemonkey.site" | sudo tee "$git_credentials_path"
        git config --global credential.helper "store --file $git_credentials_path"
        echo "GitLab credentials configured."
    fi

if [ -n "$GITLAB_URL" ] && [ ! -d "/home/coder/$PROJECT_NAME" ]; then
    git clone "$GITLAB_URL" /home/coder/"$PROJECT_NAME" || { echo "Failed to clone from $GITLAB_URL"; exit 1; }
elif [ -d "/home/coder/$PROJECT_NAME" ]; then
    echo "Repository '$PROJECT_NAME' already cloned. Skipping clone."
else
    echo "GITLAB_URL not set. Skipping clone."
fi

if sudo chmod -R u+rw,g+rw,o+rw /home/coder ; then
    echo "Permissions have been successfully changed."
else
    echo "Failed to change permissions."
    exit 1
fi

if [ -n "$PROJECT_NAME" ]; then
    cd "/home/coder/$PROJECT_NAME" || { echo "Failed to change directory to $PROJECT_NAME"; exit 1; }
else
    echo "PROJECT_NAME not set. Staying in the current directory."
fi
# Set up Go environment
if [ -d /usr/local/go/bin ]; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/coder/.profile
        source /home/coder/.profile
fi

if [ -d /opt/venv ]; then
    echo "source /opt/venv/bin/activate" >> /home/coder/.bashrc
    source /opt/venv/bin/activate
    echo "venv activated!"
fi

exec code-server --bind-addr 0.0.0.0:$PORT --app-name "Oasis" --base-path /proxy/$SERVER_PORT --welcome-text "환영합니다 ${USER_NAME}! 설정하신 패스워드를 입력해주세요."
