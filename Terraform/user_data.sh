#!/bin/bash
set -e

# Actualizar e instalar dependencias
sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3 python3-venv python3-pip nginx nodejs npm

# 1. CLONAR REPO (En la home de ubuntu para que coincida con el servicio)
cd /home/ubuntu
git clone https://github.com/cuellarcarla/emberlight-aws.git
cd emberlight-aws/Gemini_chatbot/EmberLight

# 2. BACKEND (Django)
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install django python-dotenv djangorestframework django-cors-headers psycopg2-binary google-generativeai gunicorn

# Crear archivo .env básico (Asegúrate de poner tus keys reales luego o por SSH)
echo "DEBUG=False" > .env
echo "ALLOWED_HOSTS=emberlight.mehdi.cat,www.emberlight.mehdi.cat" >> .env

# 3. FRONTEND (React/Vue)
cd /home/ubuntu/emberlight-aws/frontend
npm install
npm run build

# Configurar archivos estáticos en Nginx
sudo rm -rf /var/www/emberlight
sudo mkdir -p /var/www/emberlight
sudo cp -r build/* /var/www/emberlight/
sudo chown -R www-data:www-data /var/www/emberlight

# 4. CONFIGURACIÓN DE NGINX
sudo tee /etc/nginx/sites-available/emberlight > /dev/null <<EOF
server {
    listen 80;
    server_name emberlight.mehdi.cat www.emberlight.mehdi.cat;

    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
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
sudo systemctl restart nginx

# 5. CONFIGURACIÓN DE GUNICORN (Systemd)
sudo tee /etc/systemd/system/gunicorn.service > /dev/null <<EOL
[Unit]
Description=gunicorn daemon para EmberLight
After=network.target

[Service]
User=ubuntu
Group=www-data
# RUTA CORREGIDA:
WorkingDirectory=/home/ubuntu/emberlight-aws/Gemini_chatbot/EmberLight
Environment="PATH=/home/ubuntu/emberlight-aws/Gemini_chatbot/EmberLight/venv/bin"
ExecStart=/home/ubuntu/emberlight-aws/Gemini_chatbot/EmberLight/venv/bin/gunicorn EmberLight.wsgi:application --bind 127.0.0.1:8000

[Install]
WantedBy=multi-user.target
EOL

# Iniciar Gunicorn
sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl start gunicorn
