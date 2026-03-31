#!/bin/bash
set -e

sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3 python3-venv python3-pip nginx nodejs npm

# Clonar el repo y entrar en el directorio correcto
git clone https://github.com/cuellarcarla/emberlight-aws.git
cd emberlight-aws/Gemini_chatbot/EmberLight

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install django python-dotenv djangorestframework django-cors-headers psycopg2-binary google-generativeai gunicorn

pip freeze > requirements.txt
pip install -r requirements.txt

cd ../../frontend
npm install
npm run build

sudo rm -rf /var/www/emberlight
sudo mkdir -p /var/www/emberlight
sudo cp -r build/* /var/www/emberlight/

# Escribir la configuración de nginx SIN usar nano
sudo tee /etc/nginx/sites-available/emberlight > /dev/null <<EOF
server {
    listen 80;
    server_name www.emberlight.mehdi.cat;

    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /auth/ {
        proxy_pass http://127.0.0.1:8000/auth/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /admin/ {
        proxy_pass http://127.0.0.1:8000/admin/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location / {
        root /var/www/emberlight;
        try_files \$uri /index.html;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/emberlight /etc/nginx/sites-enabled/emberlight
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

SERVICE_NAME=gunicorn
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

# Crea el archivo de servicio systemd
sudo tee "$SERVICE_PATH" > /dev/null <<EOL
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/EmberLight_Projecte2/Gemini_chatbot/EmberLight
Environment="PATH=/home/ubuntu/EmberLight_Projecte2/Gemini_chatbot/EmberLight/venv/bin"
ExecStart=/home/ubuntu/EmberLight_Projecte2/Gemini_chatbot/EmberLight/venv/bin/gunicorn EmberLight.wsgi:application --bind 0.0.0.0:8000

[Install]
WantedBy=multi-user.target
EOL

# Recarga systemd para reconocer el nuevo servicio
sudo systemctl daemon-reload

# Habilita el servicio para que arranque al iniciar el sistema
sudo systemctl enable "$SERVICE_NAME"

# Inicia el servicio
sudo systemctl start "$SERVICE_NAME"

# Muestra el estado del servicio
sudo systemctl status "$SERVICE_NAME" --no-pager

