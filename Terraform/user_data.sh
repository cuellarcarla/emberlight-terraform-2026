#!/bin/bash
# Esperar a que la red esté lista (Máximo 10 intentos)
for i in {1..10}; do
  if ping -c 1 google.com &> /dev/null; then
    echo "Internet detectado, procediendo..."
    break
  fi
  echo "Esperando red... (intento $i)"
  sleep 10
done

set -e

sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3 python3-venv python3-pip nginx nodejs npm

# 1. Clonar en la carpeta de usuario para evitar líos de permisos
cd /home/ubuntu
git clone https://github.com/cuellarcarla/emberlight-aws.git
cd emberlight-aws

# 2. REEMPLAZO AUTOMÁTICO DE DOMINIOS (Aquí está la clave)
grep -rl "karura.cat" . | xargs sed -i 's/karura.cat/mehdi.cat/g'

# 3. BACKEND
cd Gemini_chatbot/EmberLight
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install django python-dotenv djangorestframework django-cors-headers psycopg2-binary google-generativeai gunicorn
# (Aquí deberías ejecutar python manage.py migrate si la DB es nueva)

# 4. FRONTEND
cd /home/ubuntu/emberlight-aws/frontend
npm install
npm run build
sudo rm -rf /var/www/emberlight
sudo mkdir -p /var/www/emberlight
sudo cp -r build/* /var/www/emberlight/
sudo chown -R www-data:www-data /var/www/emberlight

# 5. NGINX (Ajustado)
sudo tee /etc/nginx/sites-available/emberlight > /dev/null <<EOF
server {
    listen 80;
    server_name emberlight.mehdi.cat www.emberlight.mehdi.cat;
    location / {
        root /var/www/emberlight;
        try_files \$uri /index.html;
    }
    location ~ ^/(api|auth|admin)/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/emberlight /etc/nginx/sites-enabled/emberlight
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# 6. GUNICORN (Ruta exacta)
sudo tee /etc/systemd/system/gunicorn.service > /dev/null <<EOL
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/emberlight-aws/Gemini_chatbot/EmberLight
Environment="PATH=/home/ubuntu/emberlight-aws/Gemini_chatbot/EmberLight/venv/bin"
ExecStart=/home/ubuntu/emberlight-aws/Gemini_chatbot/EmberLight/venv/bin/gunicorn EmberLight.wsgi:application --bind 127.0.0.1:8000

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl restart gunicorn
