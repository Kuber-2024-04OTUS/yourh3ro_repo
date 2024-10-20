#!/bin/bash

# Массив с IP-адресами узлов
nodes=("158.160.5.137" "89.169.165.39" "84.201.153.121" "158.160.29.237")

# Адрес реестра без TLS
HARBOR_REGISTRY="harbor.158.160.5.137.nip.io"

# Путь к файлу конфигурации registry на узлах
REGISTRY_FILE="/etc/rancher/k3s/registries.yaml"

# Команды для добавления конфигурации и перезапуска k3s
commands=$(cat <<EOF
if [ -f "$REGISTRY_FILE" ]; then
    echo "Файл $REGISTRY_FILE уже существует, обновляем его..."
else
    echo "Создаем файл $REGISTRY_FILE..."
    sudo mkdir -p /etc/rancher/k3s
fi

# Добавляем или обновляем настройки insecure registry
sudo tee "$REGISTRY_FILE" > /dev/null <<EOL
mirrors:
  "$HARBOR_REGISTRY":
    endpoint:
      - "https://$HARBOR_REGISTRY"
configs:
  "$HARBOR_REGISTRY":
    tls:
      insecure_skip_verify: true
EOL

# Перезапускаем k3s
echo "Перезапускаем k3s..."
if systemctl list-units --type=service | grep -q "k3s-agent"; then
    sudo systemctl restart k3s-agent
else
    sudo systemctl restart k3s
fi
EOF
)

# Подключаемся к каждому узлу и выполняем команды
for node in "${nodes[@]}"; do
    echo "Подключение к узлу $node..."
    ssh yc-user@"$node" "$commands"
    echo "Конфигурация завершена на узле $node."
done

echo "Все узлы настроены."
