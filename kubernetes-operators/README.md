## ДЗ#7 Создание собственного CRD

### Задания:
- Создайте манифест объекта CustomResourceDefinition со следующими параметрами:
  - Уровень объекта: namespace
  - Api group: otus.homework
  - Kind: MySQL
  - Plural name: mysqls
  - Версия: v1  
- Объект должен иметь следующие обязательные атрибуты и правила их валидации (все полные строковые):
  - Image: определяет Docker-образ для создания
  - Database: имя базы данных
  - Password: пароль от БД
  - Storage_size: размер хранилища под базу
- Создайте манифесты ServiceAccount, ClusterRole и ClusterRoleBinding, описывающие сервисный аккаунт с полными правами на доступ к API серверу.
- Создайте манифест deployment для оператора, указав ранее созданный ServiceAccount и образ roflmaoinmysoul/mysql-operator:1.0.0.
- Создайте манифест кастомного объекта kind: MySQL, валидный для применения (см. атрибуты CRD, созданного ранее).

- Примените все манифесты и убедитесь, что CRD создан, оператор работает и при создании кастомного ресурса типа MySQL создает Deployment с указанным образом mysql, service для него, PV и PVC. При удалении объекта типа MySQL удалятся все созданные для него ресурсы.

#### Задание *:
- Измените манифест ClusterRole, описав в нем минимальный набор прав доступа, необходимых для вашего CRD, и убедитесь, что функциональность не пострадала.
Управление самим ресурсом CRD.
Создание и удаление ресурсов типа Service, PV, PVC.

#### Задание **:
- Создайте свой оператор, который будет реализовывать следующий функционал:
  - При создании в кластере объектов с типом MySQL (mysqls.otus.homework/v1) будет создаваться deployment с заданным образом mysql, сервис типа ClusterIP, PV и PVC заданного размера.
  - При удалении объекта с типом MySQL будут удаляться все ранее созданные для него ресурсы.

### Подготовка
Для выполнения задания с ** нужно установить golang и kubebuilder   
Я использовал версии:
```
$ go version
go version go1.22.4 linux/amd64

$ kubebuilder version
Version: main.version{KubeBuilderVersion:"4.0.0", KubernetesVendor:"1.27.1", GitCommit:"6c08ed1db5804042509a360edd971ebdc4ae04d8", BuildDate:"2024-05-24T08:36:23Z", GoOs:"linux", GoArch:"amd64"}
```
### Запуск 
Для Задания с CRD `roflmaoinmysoul/mysql-operator:1.0.0`
```sh
kubectl apply -f crd/
```

Для задания с собственным CRD
```sh
# Передти в каталог с crd
$ cd kubernetes-operators/golang-mysql-crd
# Сделать кодогенерацию и манифесты
$ make generate && make manifests
# Установить crd в кластер
$ make install 
# Создать объект MySQL, при необходимости, предварительно отредактировав его 
# $ vim kubernetes-operators/golang-mysql-crd/config/samples/mysql_v1_mysql.yaml
$ kubectl apply -f kubernetes-operators/golang-mysql-crd/config/samples/mysql_v1_mysql.yaml
# Запустить режиме разработки, что бы убедиться, что все работает как ожидается
$ make run
# Проверить с помощью 
# $ kubectl get all 
# Что все необходимые ресурсы (deploy,svc,pv,pvc) созданы

# Собрать контейнер с оператором
$ make docker-build IMG=mysql-operator:1.0.0
# Задеплоить контейнер в кластер 
$ make deploy IMG=mysql-operator:1.0.0
```

### Описание решения
#### Основное задание и задание с *
Задание с CRD `roflmaoinmysoul/mysql-operator:1.0.0`
1. В файле `mysql-crd.yaml` описан Объект Namespce уровня `CustomResourceDefinition` MySQL, так же api этого и spec объекта, на основании которых в дальнейшем создается custom resource
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: mysqls.otus.homework
spec:
  group: otus.homework
  scope: Namespaced
  names:
    plural: mysqls
    singular: mysql
    kind: MySQL
    shortNames:
      - mysql
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                image: 
                  type: string
                database:
                  type: string
                password:
                  type: string
                storage_size:
                  type: string

```
2. В файле `mysql-cr.yaml` описан ресурс MySQL из которого mysql-оператор дальнейшем будет создавать другие объекты
```yaml 
apiVersion: otus.homework/v1
kind: MySQL
metadata:
  name: my-mysql-instance
spec:
  image: mysql:5.7
  database: mydb
  password: veryStr0ngPa$$word
  storage_size: 5Gi
```
3. Файл `mysql-rbac.yaml` описывает serviceAccount, ClusterRole и ClusterRoleBuilding с учетом требований задания с *
```yaml
...
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: mysql-operator-role
rules:
- apiGroups: [""]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: [""]
  resources: ["services", "persistentvolumes", "persistentvolumeclaims"]
  verbs: ["create", "delete"]
  ...
```
4. Файл `mysql-deployment.yaml` описывает deployment оператора. После deplotment оператора, если все настроено правильно, в кластере автоматически создаются deployment, svc, pv, pvc для инстанса MySQL
5. Лично у меня "с ходу" не завелось, пришлось править кое что:
Суть в том что после создания operator instance он сам делает deployment, который делает pod-ы  
У меня не запускался pod `my-mysql-instance-78fd5fb64b-54psd`  
С ошибкой:
```
0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
```
Дальше пошел смотреть pv, pvc и увидел что они не связались:
```
Cannot bind to requested volume "my-mysql-instance-pv": storageClassName does not match
```
В итоге, копаясь и все везде проверяя, увидел что PersistentVolume создается с `storageClassName: standart`, в то время как у меня storageClass по-умолчанию `hostpath`  
Ну и тут 2 решения, либо сделать pv standart руками, либо, как я 
`kubectl edit pv my-mysql-instance-pv`
И просто подредактировал storageClassname  

#### Задание с **
Используя Golang и Kubebuilder написал CRD. Умеет создавать Deployment, Service, PersistentVolumeClaim и PersistentVolume. Так же при удалении ресурса, все созданное удаляется. Так же не все функции возвращают ошибки и вообще обработка ошибок у меня плохая, что не является Go Way. Но, я далеко не разработчик  
Как говорится:
```
Это не много, но это честная работа
```
![alt text](../img/image15.png)

1. В файле `kubernetes-operators/golang-mysql-crd/api/v1/mysql_types.go` производится определение api и spec. Так же, прописаны некоторые валидации. По сути, это аналог файла `mysql-crd.yaml` из прошлого задания
```go
type MySQLSpec struct {
    ...
	// Database is the name of the database
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinLength=1
	// +kubebuilder:validation:MaxLength=64
	Database string `json:"database,omitempty"`
    ...
}
```
Комментарии, которые начинаются с // +kubebuilder являются встроенными функциями фреймворка [kubebuilder markers](https://kubebuilder.io/reference/markers) и влияют на генерацию ресурсов.
```go
    // Элемент является обязательным
	// +kubebuilder:validation:Required
    // Минимальная длинна 1 символ
	// +kubebuilder:validation:MinLength=1
    // Максимальная длинна 64 символа
    // Это ограничение я взял из документации MySQL
    // https://dev.mysql.com/doc/refman/8.0/en/identifier-length.html
	// +kubebuilder:validation:MaxLength=64
```

2. В файле `kubernetes-operators/golang-mysql-crd/config/samples/mysql_v1_mysql.yaml` описан custom resource, который просто применяется в кластер, как `mysql-cr.yaml` из прошлого задания
```yaml
apiVersion: mysql.otus.homework/v1
kind: MySQL
metadata:
  labels:
    app.kubernetes.io/name: golang-mysql-crd
    app.kubernetes.io/managed-by: kustomize
  name: mysql-sample
spec:
  name: yourhero-db
  image: mysql:5.7
  database: urdb
  user: user
  password: userpa$$word
  rootPassword: rootpa$$word
  storage: 10Gi
```

3. В файле `kubernetes-operators/golang-mysql-crd/internal/controller/mysql_controller.go` описана логика работы оператора, а конкретно, в функции `Reconcile` выполняется поиск ресурсов и "принятие решения". Сами шалоны ресуров описаны в остельных функциях. Приведу пример с deployment, остальные функции реализованы аналогично:
```go
func (r *MySQLReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	// Получаем объект MySQL из кластера
	mysql := &mysqlv1.MySQL{}
	if err := r.Get(ctx, req.NamespacedName, mysql); err != nil {
		if errors.IsNotFound(err) {
			// Если объект MySQL не найден, возвращаем управление
			return ctrl.Result{}, nil
		}
		// Если произошла другая ошибка, возвращаем ошибку
		return ctrl.Result{}, err
	}

    ...
    // Проверяем, если объект MySQL удален
	if !mysql.DeletionTimestamp.IsZero() {
		// Удаляем Deployment
		deployment := r.deploymentForMysql(mysql)
		if err := r.Delete(ctx, deployment); err != nil {
			return ctrl.Result{}, err
		}
    ...
    }

	// Проверяем, если объект Deployment уже существует
	deployment := r.deploymentForMysql(mysql)
	foundDeployment := &appsv1.Deployment{}
	if err := r.Get(ctx, types.NamespacedName{Name: deployment.Name, Namespace: deployment.Namespace}, foundDeployment); err != nil {
		if errors.IsNotFound(err) {
			// Если объект Deployment не найден, создаем его
			if err := r.Create(ctx, deployment); err != nil {
				return ctrl.Result{}, err
			}
		} else {
			// Если произошла другая ошибка, возвращаем ошибку
			return ctrl.Result{}, err
		}
	}
    ...

	// Возвращаем управление, выходим из функции
	return ctrl.Result{}, nil

``` 
Сама функция deploymentForMysql принимает в себя customResource и возвращает на его основе deployment:
```go
func (r *MySQLReconciler) deploymentForMysql(cr *mysqlv1.MySQL) *appsv1.Deployment {
    // Создаем мапу с лейблами
	labels := map[string]string{
		"app":     cr.Name,
		"apptype": "mysql",
	}

    // Мапим Env vars MYSQL и "мои" значения из спеки (mysql_types.go)
	containerEnvVars := []corev1.EnvVar{
		{
			Name:  "MYSQL_DATABASE",
			Value: cr.Spec.Database,
		},
		{
			Name:  "MYSQL_USER",
			Value: cr.Spec.User,
		},
		{
			Name:  "MYSQL_PASSWORD",
			Value: cr.Spec.Password,
		},
		{
			Name:  "MYSQL_ROOT_PASSWORD",
			Value: cr.Spec.RootPassword,
		},
	}

    // Описываем объект deployment 
	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cr.Name + "-deployment",
			Namespace: cr.Namespace,
		},
		Spec: appsv1.DeploymentSpec{
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: labels,
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  cr.Name,
							Image: cr.Spec.Image,
							Env:   containerEnvVars,
						},
					},
				},
			},
		},
	}

    // Устанавливаю CR в качестве владельца и контроллера развертывания
	controllerutil.SetControllerReference(cr, deployment, r.Scheme)
    
    // Возвращаю объект deployment
	return deployment
}

```