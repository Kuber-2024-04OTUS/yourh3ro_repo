## ДЗ#3 Сетевое взаимодействие Pod, сервисы  

### Задания:
- Создать кастомный образ Nginx, который отдает свои метрики на определенном endpoint (пример из официальной документации в разделе ссылок).
- Установить Prometheus-operator в кластер удобным для вас способом. Рекомендуется установить его либо по ссылке из официальной документации, либо через Helm-чарт.
- Создать deployment, запускающий ваш кастомный образ Nginx, и service для него.
- Установить в кластере ingress-контроллер nginx.
- Настроить запуск Nginx prometheus exporter (отдельным подом или в составе пода с Nginx - не принципиально) и сконфигурировать его для сбора метрик с Nginx.
- Создать манифест serviceMonitor, описывающий сбор метрик с подов, которые вы создали.

### Подготовка
1. Необходимо установить helm

### Запуск 
1. Установить Prometheus Operator
```
helm install my-prometheus-release oci://registry-1.docker.io/bitnamicharts/kube-prometheus
```
2. Сбилдить образ custom-nginx 
```
cd kubernetes-monitoring/custom-nginx/ 
./build.sh
```
2. `kubectl apply -f kubernetes-monitoring/`

### Описание решения
1. В каталоге custom-nginx лежит dockerfile и конфиг deafult.conf
Конфиг полностью повторяет дефолтный, за исключением того, что добавлен location для получения метрик:
```
    location = /basic_status {
        stub_status;
    }
```
В моем базовом образе nginx уже вкелючена поддержка stub_status, это можно увидеть командой:
```sh
docker run nginx:1.25.5-bookworm /bin/sh -c "nginx -V 2>&1 | grep -o with-http_stub_status_module"
```
На самом деле этот шаг можно было реализовать с пощью configmap, но по условиям задания нудно сделать кастомный image
2. Я установил Prometheus через helm
```
helm install my-prometheus-release oci://registry-1.docker.io/bitnamicharts/kube-prometheus
```
3. Установил ingress-контроллер nginx так же через helm
```
helm install my-nginx-release oci://ghcr.io/nginxinc/charts/nginx-ingress --version 1.2.2
```
4. Для собранного custom-nginx сконфигурированны `custom-nginx-deployment.yaml` и `custom-nginx-service.yaml` с deployment и service для образа из п.1 соответвенно
5. Для nginx exporter созданы:
`nginx-exporter-deployment.yaml` в котором описывается deployment для nginx exporter:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-exporter
  labels:
    app: nginx-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-exporter
  template:
    metadata:
      labels:
        app: nginx-exporter
    spec:
      containers:
      - name: nginx-exporter
        image: nginx/nginx-prometheus-exporter:1.1.0
        args:
        - --nginx.scrape-uri=http://custom-nginx:80/basic_status # "смотрит" на service custom nginx из п.2 по lacation stub_status 
        ports:
        - name: nginx-exporter
          containerPort: 9113
```
и `nginx-exporter-service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-exporter 
  labels:
    app: nginx-exporter
spec:
  ports:
  - name: nginx-exporter
    port: 9113
    targetPort: nginx-exporter
  selector:
    app: nginx-exporter
```
6. Для того, что бы Prometheus начал собирать метрики с nginx exporter, создан `nginx-exporter-servicemonitor.yaml`. Это Custom Resource для Prometheus Operator:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx-exporter-servicemonitor
  labels:
    app: nginx-exporter
spec:
  selector:
    matchLabels:
      app: nginx-exporter
  endpoints:
    - port: nginx-exporter
      interval: 30s
```