#!/bin/bash


set -e

# Экспортируем переменную окружения KUBECONFIG для доступа в кластер
export KUBECONFIG=$(pwd)/k3s-install/k3s.yaml

# Функция для логирования
log () {
    echo "[$(date)] [INFO] $1"
}

# Функция для проверки наличия и создания namespace
ensure_namespace () {
    local namespace=$1
    kubectl get namespace $namespace || kubectl create namespace $namespace
}

# Функция для установки административных инструментов
install_admin_tools () {
    log "Installing admin components to kube-system namespace"
    log "Installing headlamp"
    # Установка headlamp 
    kubectl apply -n kube-system -f ./admin/headlamp/headlamp.yaml
    kubectl apply -n kube-system -f ./admin/headlamp/ingress-headlamp.yaml
    kubectl apply -n kube-system -f ./admin/headlamp/rbac-headlamp.yaml


    log "Installing longhorn"
    # Установка longhorn
    ensure_namespace longhorn-system
    kubectl apply -n longhorn-system -f ./admin/longhorn/longhorn.yaml
    kubectl apply -n longhorn-system -f ./admin/longhorn/ingress-longhorn.yaml

    log "Enabling traefik dashboard"
    # Так как я использую k3s, traefik уже установлен 
    # поэтому просто включаем dashboard через изменения конфига
    kubectl apply -n kube-system -f ./admin/traefik-dashboard/traefik-custom-conf.yaml
    kubectl apply -n kube-system -f ./admin/traefik-dashboard/ingress-traefik-dashboard.yaml
}

install_registry () {
    log "Installing Harbor registry"
    # Проверяем, что Harbor уже установлен
    if helm list --namespace harbor | grep -q harbor; then
        log "Harbor already installed"
    else
        # Если Harbor не установлен, устанавливаем
        log "Installing Harbor"
        helm repo add harbor https://helm.goharbor.io
        helm repo update
        helm install harbor harbor/harbor --create-namespace --namespace harbor -f ./registry/harbor/values.yaml
    fi
}

# Функция для установки CI/CD инструментов
install_cicd_tools () {
    log "Installing Tekton"
    ensure_namespace tekton-pipelines
    ensure_namespace tekton-pipelines-resolvers
    # Установка Tekton Pipelines и других компонентов
    kubectl apply -f ./cicd/tekton/tekton.pipelines.0.62.3.yaml
    kubectl apply -f ./cicd/tekton/tekton.triggers.0.29.1.yaml
    kubectl apply -f ./cicd/tekton/tekton.interceptors.0.29.1.yaml
    kubectl apply -f ./cicd/tekton/tekton.dashboard.0.51.0.yaml
    kubectl apply -f ./cicd/tekton/shared-workspace.yaml
    kubectl apply -f ./cicd/tekton/ingress-tekton-dashboard.yaml

    log "Installing Argo CD"
    ensure_namespace argocd
    # Установка Argo CD
    kubectl apply -n argocd -f ./cicd/argo-cd/install/install.yaml
    kubectl apply -n argocd -f ./cicd/argo-cd/install/argocd-config.yaml
    kubectl apply -n argocd -f ./cicd/argo-cd/install/argocd-ingress.yaml
}

# Функция для инициализации CI пайплайна
init_ci_pipeline () {
    log "Installing Tekton pipeline for apps"
    # Инициализация Tekton пайплайна для приложений
    kubectl apply -n default -f ./cicd/pipeline/dotnet-app-build.yaml
    kubectl apply -n default -f ./cicd/pipeline/go-app-build.yaml
    kubectl apply -n default -f ./cicd/pipeline/python-app-build.yaml
    kubectl apply -n default -f ./cicd/pipeline/harbor-registry-secret.yaml
    kubectl apply -n default -f ./cicd/pipeline/pipeline-rbac.yaml
}

# Функция для инициализации CD пайплайна
init_cd_pipeline () {
    log "Init Argo CD pipeline"
    # Инициализация Argo CD деплоя приложений
    kubectl apply -n argocd -f ./cicd/argo-cd/cd/argocd-apps.yaml
}
# Функция для установки мониторинга
install_monitoring () {
    log "Installing kube-prometheus-stack"
    # Проверяем, что kube-prometheus-stack уже установлен
    if helm list --namespace monitoring | grep -q kube-prometheus-stack; then
        log "kube-prometheus-stack already installed"
    else
        log "Installing kube-prometheus-stack"
        # Если kube-prometheus-stack не установлен, устанавливаем
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        ensure_namespace monitoring
        helm install --namespace monitoring --create-namespace kube-prometheus-stack prometheus-community/kube-prometheus-stack -f ./monitoring/kube-prometheus-stack/values.yaml
        helm update --namespace monitoring --create-namespace kube-prometheus-stack prometheus-community/kube-prometheus-stack -f ./monitoring/prometheus/additional-scrape-configs.yaml
    fi

}

main () {
    log "Installing admin tools..."
    install_admin_tools

    log "Installing registry..."
    install_registry

    log "Installing CI/CD tools..."
    install_cicd_tools

    log "Initializing CI/CD pipeline..."
    init_ci_pipeline

    log "Initializing CD pipeline..."
    init_cd_pipeline

    log "Installing monitoring..."
    install_monitoring
}

main "$@"