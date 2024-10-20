# Репозиторий для выполнения домашних заданий курса "Инфраструктурная платформа на основе Kubernetes-2024-02" 

[ДЗ#2 Kubernetes controllers. ReplicaSet, Deployment, DaemonSet](kubernetes-controllers/README.md)  
[ДЗ#3 Сетевое взаимодействие Pod, сервисы](kubernetes-networks/README.md)  
[ДЗ#4 Volumes, StorageClass, PV, PVC](kubernetes-volumes/README.md)  
[ДЗ#5 Настройка сервисных аккаунтов и ограничение прав для них](kubernetes-security/README.md)  
[ДЗ#6 Шаблонизация манифестов приложения, использование Helm. Установка community Helm charts.](kubernetes-templating/README.md)  
[ДЗ#7 Создание собственного CRD](kubernetes-operators/README.md)  
[ДЗ#8 Мониторинг приложения в кластере](kubernetes-monitoring/README.md)   
[ДЗ#9 Сервисы централизованного логирования для Kubernetes](kubernetes-logging/README.md)   
[ДЗ#10 GitOps и инструменты поставки](kubernetes-gitops/README.md)   
[ДЗ#11 Хранилище секретов для приложения. Vault.](kubernetes-vault/README.md)   
[ДЗ#12 Установка и использование CSI драйвера](kubernetes-csi/README.md)   
[ДЗ#13 Диагностика и отладка в Kubernetes](kubernetes-debug/README.md)   
[ДЗ#14 Подходы к развертыванию и обновлению production-grade кластера](kubernetes-prod/README.md)   
## Tricks, Tools, Hints

### k9s
[K9s - Kubernetes CLI To Manage Your Clusters In Style!](https://github.com/derailed/k9s) - CUI for k8s clusters  
https://habr.com/ru/companies/flant/articles/524196/ - статья по функция и возможностям  

Установка:  
На странице есть инструкции пол установке под все платформы. 
Для Ubuntu 22.04.4 LTS (WSL2)
```sh
curl -L https://github.com/derailed/k9s/releases/download/v0.32.4/k9s_linux_amd64.deb -o k9s.deb
sudo dpkg -i k9s.deb
```

### krew менеджер плагинов kubectl
https://krew.sigs.k8s.io/docs/user-guide/setup/install/

### kubeconfig-manager менеджер kubeconfig
https://github.com/kalgurn/kubeconfig-manager

### k3sup утилита для создания кластеров k3s
https://github.com/alexellis/k3sup
