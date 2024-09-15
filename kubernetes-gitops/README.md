## ДЗ#10 GitOps и инструменты поставки

### Задания:  
- Данное задание будет выполняться в managed k8s в Yandex cloud.
- Разверните managed Kubernetes кластер в Yandex cloud любым удобным вам способом.
- Для кластера создайте два пула нод:
  - Для рабочей нагрузки (можно 1 ноду).
  - Для инфраструктурных сервисов (также хватит пока и одной ноды).
- Для инфраструктурной ноды/нод добавьте taint, запрещающий на неё планирование подов с посторонней нагрузкой - node-role=infra:NoSchedule.
- Приложите к ДЗ вывод команд kubectl get node -o wide --show-labels и kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints показывающий конфигурацию нод в вашем кластере.
- Установите в кластер ArgoCD с помощью Helm-чарта.
  - Необходимо сконфигурировать параметры установки так, чтобы компонент ArgoCD устанавливался исключительно на infra-ноду (добавить соответствующий toleration для обхода taint, а также nodeSelector или nodeAffinity на ваш выбор, для планирования подов только на заданные ноды).
  - Приложите к ДЗ values.yaml конфигурации установки ArgoCD и команду самой установки чарта.
- Создайте project с именем Otus.
  - В качестве Source-репозитория укажите ваш репозиторий с ДЗ курса.
  - В качестве Destination должен быть указан ваш кластер, в который установлен ArgoCD.
  - Приложите манифест, описывающий project к ДЗ.
- Создайте приложение ArgoCD
  - В качестве репозиторию укажите ваше приложение из ДЗ
kubernetes-networks
  - Sync policy – manual
  - Namespace - homework
  - Проект – Otus. Убедитесь, что есть необходимые настройки,
длю созданию и установки в namespace, который описан в ДЗ
kubernetes-networks
  - Убедитесь, что nodeSelector позволюет установить
приложение на одну из нод кластера
  - Приложите манифест, описывающий установку приложению
к результатам ДЗ
- Создайте приложение ArgoCD
  -  В качестве репозиторию укажите ваше приложение из ДЗ
kubernetes-templating
  - Укажите директорию, в которой находитсю ваш helm-чарт,
который вы разрабатывали самостоютельно
  - SyncPolicy – Auto, AutoHeal – true, Prune – true.
  - Проект – Otus.
  - Namespace – HomeworkHelm. Убедитесь, что установка чарта
будет остуществлютьсю в отличный от первого приложению
namespace.
  - Параметр, задающий количество реплик запускаемого
приложению должен переопределютьсю в конфигураøии
  - Приложите манифест, описывающий установку приложению
к результатам ДЗ
  - Namespace – HomeworkHelm. Убедитесь, что установка чарта будет осуществляться в отличный от первого приложения namespace.
  - Параметр, задающий количество реплик запускаемого приложения должен переопределяться в конфигурации.
  - Приложите манифест, описывающий установку приложения к результатам ДЗ.
### Запуск 
- Создать в yc необходимые ресурсы согласно описанию (Я это сделал в прошлом ДЗ)
- Добавить в helm репозитории grafana/grafana
- helm install arocd --create-namespace ./argocd
- kubectl apply -f argo

### Описание решения
#### Настройка планирования ArgoCD на Infra nodes
```
helm pull bitnami/argo-cd --untar
```
Аналогично прошлому ДЗ, я сделал pull чарта argocd и в файлах values.yaml и ./argo-cd/charts/redis/values.yaml настроил необходимые параметры:
```yaml
# Для планирования на infra nod-ы
# Сделал для всех ресурсов
...
nodeSelector: 
  node-role: infra
tolerations: 
  - key: node-role
    operator: Equal
    value: infra
    effect: NoSchedule
...
```
Далее с помощью команды:
```sh
helm install argocd argo-cd/ --namespace argocd --create-namespace
```
Установил в кластер argo-cd
Далее прешел к настройки ароекта и приложений:
Файл проекта:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  # Название проекта
  name: otus-project
  namespace: argocd
spec:
  description: Otus homework project
  sourceRepos:
      # source repo - репозиторий домашних заданий
    - 'https://github.com/Kuber-2024-04OTUS/yourh3ro_repo.git'
  destinations:
      # Любые namespace в текущем кластере
    - namespace: '*'
      server: 'https://kubernetes.default.svc'
      name: in-cluster
  # Разрешаю управеление любыми ресурсами, нужно для создания namespaces самим argocd
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
```
Приложение kubernetes-networks-app:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubernetes-networks-app
  namespace: argocd
spec:
  project: otus-project
  source:
    # Каталог с приложением
    path: kubernetes-networks
    # репозиторий домашних заданий
    repoURL: https://github.com/Kuber-2024-04OTUS/yourh3ro_repo.git
    # ветка репозитория
    targetRevision: main
    # Проходимя по директорям рекурсивно
    directory:
      recurse: true
  # точна назначения
  destination:
    # локальный кластер
    server: https://kubernetes.default.svc
    # namespace в который будет деплоиться приложение
    namespace: homework
## SyncPolicy manual используется по-умолчанию
```

Приложение kubernetes-templating-app:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubernetes-tempalting-app
  namespace: argocd
spec:
  project: otus-project
  source:
    path: kubernetes-templating/task1/otusapp-chart
    repoURL: https://github.com/Kuber-2024-04OTUS/yourh3ro_repo.git
    # Так как на момент написания ДЗ kubernetes-tempalting ветк не смержена в main, указываю ветку kubernetes-tempalting
    targetRevision: kubernetes-tempalting
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: HomeworkHelm
  # Задаю SyncPolicy согласно ДЗ
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
После применения в кластер:
```
kubectl apply -f argo
```
В argocd создается проект otus-project и 2 приложения. Приложение kubernetes-templating-app деплоится автоматически, а kubernetes-networks-app задеплоится если нажать Sync
