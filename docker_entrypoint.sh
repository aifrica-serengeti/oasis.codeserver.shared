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

    sudo touch $INIT_MARKER
    echo "Initialization complete."
fi

# 환경 변수로부터 값을 읽어서 JSON 파일 수정.
echo "Modifying JSON with environment variables..."
OLLAMA_HOST=${OLLAMA_HOST:-"http://default-host-value"}
OLLAMA_MODEL=${OLLAMA_MODEL:-"qwen2.5-coder:7b-instruct-q8_0"}

# JSON 파일 경로가 없을 경우, 디렉토리를 생성.
CONFIG_DIR="/home/coder/.continue"
CONFIG_FILE="$CONFIG_DIR/config.json"

# 경로가 없다면 경로를 생성.
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Config directory does not exist. Creating $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"
    echo "Created $CONFIG_DIR."
fi

# JSON 파일의 내용을 환경 변수에 따라 동적으로 수정.
cat <<EOF > "$CONFIG_FILE"
{
  "models": [
    {
      "title": "Qwen-coder",
      "model": "$OLLAMA_MODEL",
      "contextLength": 32768,
      "apiBase": "$OLLAMA_HOST",
      "provider": "ollama"
    }
  ],
  "customCommands": [
    {
      "name": "test",
      "prompt": "{{{ input }}}\n\nWrite a comprehensive set of unit tests for the selected code. It should setup, run tests that check for correctness including important edge cases, and teardown. Ensure that the tests are complete and sophisticated. Give the tests just as chat output, don't edit any file.",
      "description": "Write unit tests for highlighted code"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Starcoder2 3b",
    "provider": "ollama",
    "model": "starcoder2:3b"
  },
  "contextProviders": [
    {
      "name": "code",
      "params": {}
    },
    {
      "name": "docs",
      "params": {}
    },
    {
      "name": "diff",
      "params": {}
    },
    {
      "name": "terminal",
      "params": {}
    },
    {
      "name": "problems",
      "params": {}
    },
    {
      "name": "folder",
      "params": {}
    },
    {
      "name": "codebase",
      "params": {}
    }
  ],
  "slashCommands": [
    {
      "name": "edit",
      "description": "Edit selected code"
    },
    {
      "name": "comment",
      "description": "Write comments for the selected code"
    },
    {
      "name": "share",
      "description": "Export the current chat session to markdown"
    },
    {
      "name": "cmd",
      "description": "Generate a shell command"
    },
    {
      "name": "commit",
      "description": "Generate a git commit message"
    }
  ],
  "tabAutocompleteOptions": {
    "disable": true,
    "useCopyBuffer": false,
    "maxPromptTokens": 400,
    "prefixPercentage": 0.5
  },
  "allowAnonymousTelemetry": false,
  "disableIndexing": true
}
EOF

echo "JSON file has been updated with OLLAMA_HOST and OLLAMA_MODEL."

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
    echo "https://oauth2:$GITLAB_TOKEN@$GITLAB_DOMAIN" | sudo tee "$git_credentials_path"
    git config --global credential.helper "store --file $git_credentials_path"
    echo "GitLab credentials configured."
fi

# GitLab URL을 확인하고, 디렉토리가 없는 경우 클론 시도
if [ -n "$GITLAB_URL" ] && [ ! -d "/home/coder/$PROJECT_NAME" ]; then
    echo "Cloning repository from $GITLAB_URL..."
    
    # 만약 디렉토리가 남아 있으면 삭제하고 클론 시도
    if [ -d "/home/coder/$PROJECT_NAME" ]; then
        echo "Cleaning up existing directory..."
        sudo rm -rf "/home/coder/$PROJECT_NAME"
    fi

    # Git 클론 시도
    if git clone "$GITLAB_URL" /home/coder/"$PROJECT_NAME"; then
        echo "Repository cloned successfully."
    else
        echo "Failed to clone from $GITLAB_URL. Cleaning up..."
        sudo rm -rf "/home/coder/$PROJECT_NAME"
        exit 1
    fi
elif [ -d "/home/coder/$PROJECT_NAME" ]; then
    echo "Repository '$PROJECT_NAME' already exists. Skipping clone."
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

# Activate Python virtual environment
if [ -d /opt/venv ]; then
    echo "source /opt/venv/bin/activate" >> /home/coder/.bashrc
    source /opt/venv/bin/activate
    echo "venv activated!"
fi

# Start code-server
exec code-server --bind-addr 0.0.0.0:$PORT --app-name "Serengeti Functions" --welcome-text "환영합니다 ${USER_NAME}! 클립보드에 복사된 패스워드를 입력해주세요.(Ctrl + V)"
