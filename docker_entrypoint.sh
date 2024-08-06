#!/bin/bash
echo "Starting script..."
USERNAME=${USER_NAME:-"사용자"}
PORT=${PORT:-65535}
INIT_MARKER=/home/coder/.initialized

# Check if the initialization marker file exists
if [ ! -f "$INIT_MARKER" ]; then
    echo "Initializing for the first time..."
    
    # Copy the contents of /coder to /home/coder
    cp -r /coder/* /home/coder/
    echo "Copied initial files to /home/coder."
    
    
    touch $INIT_MARKER
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
        echo "https://oauth2:$GITLAB_TOKEN@gitlab.codemonkey.run" > "$git_credentials_path"
        git config --global credential.helper "store --file $git_credentials_path"
        echo "GitLab credentials configured."
    fi

if [ -n "$GITLAB_URL" ] && [ ! -d "./$PROJECT_NAME" ]; then
    git clone "$GITLAB_URL" || { echo "Failed to clone from $GITLAB_URL"; exit 1; }
elif [ -d "./$PROJECT_NAME" ]; then
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

if [ -d /home/coder/venv ]; then
    echo "source /home/coder/venv/bin/activate" >> /home/coder/.bashrc
    source /home/coder/venv/bin/activate
    echo "venv activated!"
fi

if [ -d /usr/local/go/bin ]; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
        source ~/.profile
fi

exec code-server --bind-addr 0.0.0.0:$PORT --app-name "Oasis" --welcome-text "환영합니다 ${USER_NAME}! 설정하신 패스워드를 입력해주세요."
