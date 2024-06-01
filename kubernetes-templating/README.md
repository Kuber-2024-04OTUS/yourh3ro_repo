## ДЗ#6 Шаблонизация манифестов приложения, использование Helm. Установка community Helm charts.

### Задания:
#### Задание 1

Создайте helm-chart, позволяющий деплоить приложение, которое у вас получилось при выполнении ДЗ 1-5. При этом необходимо учесть:

- Основные параметры в манифестах, такие как имена объектов, имена контейнеров, используемые образы, хосты, порты, количество запускаемых реплик должны быть заданы как переменные в шаблонах и конфигурироваться через values.yaml либо через параметры при установке релиза.
- Репозиторий и тег образа не должны быть одним параметром.
- Пробы должны быть включаемыми/отключаемыми через конфиг.
- В notes должно быть описано сообщение после установки релиза, отображающее адрес, по которому можно обратиться к сервису.
- При именовании объектов в шаблонах старайтесь придерживаться best practice из лекции.
- Добавьте в свой чарт сервис-зависимость из доступных community-чартов. Например, MySQL или Redis.

#### Задание 2

Установите Kafka из bitnami helm-чарта. Релиз должен иметь следующие параметры:

- Установлен в namespace `prod`.
- Должно быть развернуто 5 брокеров.
- Должна быть установлена Kafka версии 3.5.2.
- Для клиентских и межброкерных взаимодействий должен использоваться протокол SASL_PLAINTEXT.

Установите Kafka из bitnami helm-чарта. Релиз должен иметь следующие параметры:

- Установлен в namespace `dev`.
- Должен быть развернут 1 брокер.
- Должна быть установлена последняя доступная версия Kafka.
- Для клиентских и межброкерных взаимодействий должен использоваться протокол PLAINTEXT, авторизация для подключения к кластеру отключена.

Опишите 2 предыдущих сценария установки в helmfile и приложите получившийся helmfile.yaml (и иные файлы, если они будут).

### Подготовка
1. Необходимо убедиться, что на ноде есть label `homework=true`, это можно посмотреть командой `kubectl get nodes --show-labels`. В моем случае, label уже есть на нужной ноде. Если label нет, его необходимо создать командой `kubectl label nodes <node-name> homework=true`  
2. Если, как у меня, нет dns-сервера, необходимо добавить запись в `/etc/hosts`, `127.0.0.1 homework.otus`
```sh
echo "127.0.0.1 homework.otus" | sudo tee -a /etc/hosts
```
3. Так же, необходимо установить helm и helmfile, плагин diff для helm
```sh
helm plugin install https://github.com/databus23/helm-diff
```

### Запуск 
Для Задание 1 (каталог task1)
```sh
helm install otusapp-release ./task1/otusapp-chart
```
Для Задание 2 (каталог task2)
```sh
helm plugin install https://github.com/databus23/helm-diff
cd task2
helmfile apply
```
### Описание решения
Для выполнения Задания 1, пришлось практически полностью все переписать, по этому, привожу основные измененния по заданиям и подзаданиям:
- Основные параметры, такие как порты, количество реплик, конфигмапы и используемые образы конфигурируются в values.yaml
```yaml
## values.yaml

# Настройки сервиса
service:
  enabled: true
  name: webserver-svc
...
  ports:
    name: websrv-svc-port
    port: 8000
    targetPort: webserver-port
...
# configmap приложения
appconfigmap:
  name: app-config-map
  data:
    appsettings.env: |
      TIME_ZONE: Europe/Moscow
      LOG_LEVEL: INFO
...
# Настройки deployment
deployment:
  name: webserver
  replicas: 3
...
  webserverContainer:
    name: webserver
    image:
      name: nginx
      tag: 1.26.0-bookworm
```
- Репозиторий и тег образа задаются конструкцией:
```yaml
deployment:
...
  webserverContainer:
    name: webserver
    image:
      name: nginx
      tag: 1.26.0-bookworm
```
- Пробы включаемы/отключаемы через конфиг.
```yaml
## values.yaml
deployment:
...
    readinessProbe: 
      enabled: true

## deployment.yaml
...
          {{- if .Values.deployment.webserverContainer.readinessProbe.enabled }}
          readinessProbe:
            httpGet:
              path: /index.html
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 3
          {{- end }}
```
- В notes есть сообщение, с подсказкой, как обратиться к сервису после установки
```yaml
## NOTES.txt
...
{{- if .Values.ingress.enabled }}

To access your webserver via Ingress, use:
http://{{ .Values.ingress.host }}
or to otus app:
http://{{ .Values.ingress.host }}/index.html
{{- if .Values.deployment.metricInitContainer.enabled }}
or get metrics
http://{{ .Values.ingress.host }}/metrics.html
{{- end }}
...
```
- В heml chart добавлен redis в качестве зависимости
```yaml
## Chart.yaml
dependencies:
  - name: redis
    repository: https://charts.bitnami.com/bitnami
    version: 19.5.0
```
Для выполнения Задания 2 был создан helmfile и описано 2 релиза kafka:
| Параметр                                      | Значение для `prod`                      | Значение для `dev`                           |
|-----------------------------------------------|------------------------------------------|----------------------------------------------|
| Namespace                                     | `prod`                                   | `dev`                                        |
| Количество брокеров                           | 5                                        | 1                                            |
| Версия Kafka                                  | 3.5.2                                    | latest                   |
| Протокол для клиентских и межброкерных взаимодействий | SASL_PLAINTEXT                           | PLAINTEXT                                    |
| Авторизация для подключения к кластеру        | Включена                                 | Отключена                                    |

