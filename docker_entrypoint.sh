#!/bin/bash
echo "Starting script..."
USERNAME=${USER_NAME:-"사용자"}
# Initialize marker check
INIT_MARKER=/home/coder/.initialized
if [ -d /usr/local/go/bin ]; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
        source ~/.profile
fi
# Check if the initialization marker file exists
if [ ! -f "$INIT_MARKER" ]; then
    echo "Initializing for the first time..."
    code-server --install-extension Continue.continue
    code-server --install-extension rangav.vscode-thunder-client
    if [ -d /opt/venv ]; then
        echo "Python is installed. Installing Python extensions..."
        cp -r /opt/venv /home/coder/venv
        chown -R coder:coder /home/coder/venv
        code-server --install-extension ms-python.python
    fi
    if [ -d /usr/local/go/bin ]; then
        echo "Golang is installed. Installing Golang extensions..."
        code-server --install-extension golang.Go
    fi
    if type -p java; then
        echo "Java is installed. Installing Java extensions..."
        code-server --install-extension redhat.java
    fi
    # Git global configuration only on first initialization
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
        echo "https://oauth2:$GITLAB_TOKEN@gitlab.codemonkey.run" > "$git_credentials_path"
        git config --global credential.helper "store --file $git_credentials_path"
        echo "GitLab credentials configured."
    fi

    # Ensure the directory exists
    mkdir -p /home/coder/.continue

    # Copy the contents of /config.json to /home/coder/.continue/config.json
    cp -f /config.json /home/coder/.continue/config.json
    echo "Configuration file updated."

    # Create the initialization marker file
    touch $INIT_MARKER
    echo "Initialization complete."
fi

# Proceed with cloning if necessary
if [ -n "$GITLAB_URL" ] && [ ! -d "./$PROJECT_NAME" ]; then
    echo "GITLAB_URL is set to '$GITLAB_URL'. Cloning the repository..."
    git clone "$GITLAB_URL" || { echo "Failed to clone from $GITLAB_URL"; exit 1; }
elif [ -d "./$PROJECT_NAME" ]; then
    echo "Repository '$PROJECT_NAME' already cloned. Skipping clone."
else
    echo "GITLAB_URL not set. Skipping clone."
fi

# Set permissions
if sudo chmod -R u+rw,g+rw,o+rw /home/coder ; then
    echo "Permissions have been successfully changed."
else
    echo "Failed to change permissions."
    exit 1
fi

# Check if PROJECT_NAME is set and change to the project directory if it is
if [ -n "$PROJECT_NAME" ]; then
    echo "PROJECT_NAME is set to '$PROJECT_NAME'. Changing to the project directory..."
    cd "/home/coder/$PROJECT_NAME" || { echo "Failed to change directory to $PROJECT_NAME"; exit 1; }
else
    echo "PROJECT_NAME not set. Staying in the current directory."
fi
if [ -d /home/coder/venv ]; then
        echo "source /home/coder/venv/bin/activate" >> /home/coder/.bashrc
        source /home/coder/venv/bin/activate
        echo "venv activated!"
fi
# Start code-server and bind to all network interfaces
exec code-server --bind-addr 0.0.0.0:65535 --app-name "Oasis" --welcome-text "환영합니다 ${USER_NAME}! 설정하신 패스워드를 입력해주세요."
