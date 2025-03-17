#!/bin/bash

# Exit on error
set -e

# Update package lists
echo "Updating package lists..."
sudo apt-get update

# Install necessary system packages
echo "Installing necessary packages..."
sudo apt-get install -y nginx python3 python3-pip python3-venv git tmux

# Configure Nginx
echo "Configuring Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    server_name cognito.fun www.cognito.fun;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF'

# Test and reload Nginx
echo "Testing and reloading Nginx..."
sudo nginx -t && sudo systemctl reload nginx
sudo ufw allow 'Nginx Full'

# Create project directory if it doesn't exist
PROJECT_DIR="/home/ubuntu/dispill-alar"
echo "Setting up project directory at $PROJECT_DIR..."
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Clone the repository if it doesn't exist
if [ ! -d ".git" ]; then
    echo "Cloning the repository..."
    git clone https://github.com/yourusername/dispill-alar.git .
fi

# Create and activate virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python packages
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install fastapi uvicorn[standard] firebase-admin pytz

# Install any additional requirements if you have a requirements.txt
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
fi

# Create systemd service file
echo "Creating systemd service file..."
sudo bash -c 'cat > /etc/systemd/system/dispill-api.service <<EOF
[Unit]
Description=Dispill API Service
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/dispill-alar
ExecStart=/home/ubuntu/dispill-alar/venv/bin/uvicorn main:app --host 0.0.0.0 --port 3000
Restart=always
RestartSec=5
StartLimitBurst=5
StartLimitIntervalSec=60

[Install]
WantedBy=multi-user.target
EOF'

# Create a directory for Firebase credentials if needed
mkdir -p credentials

# Reload systemd, enable and start the service
echo "Starting the API service..."
sudo systemctl daemon-reload
sudo systemctl enable dispill-api
sudo systemctl start dispill-api

# Check service status
echo "Checking service status..."
sudo systemctl status dispill-api

# Alternative method using tmux
echo "You can also run the server using tmux with this command:"
echo "tmux new -d -s dispill 'cd $PROJECT_DIR && source venv/bin/activate && uvicorn main:app --host 0.0.0.0 --port 3000'"

echo "Installation complete! The FastAPI server should be running on port 3000 and accessible through Nginx."