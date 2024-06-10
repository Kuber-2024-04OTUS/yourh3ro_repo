/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"

	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	mysqlv1 "github.com/Kuber-2024-04OTUS/yourh3ro_repo/kubernetes-operators/golang-mysql-crd/api/v1"
)

// MySQLReconciler reconciles a MySQL object
type MySQLReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=mysql.otus.homework,resources=mysqls,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=mysql.otus.homework,resources=mysqls/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=mysql.otus.homework,resources=mysqls/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=pods,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=persistentvolumeclaims,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=events,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=persistentvolumes,verbs=get;list;watch;create;update;patch;delete

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the MySQL object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.18.2/pkg/reconcile

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

	// Проверяем, если объект MySQL удален
	if !mysql.DeletionTimestamp.IsZero() {
		// Удаляем Deployment
		deployment := r.deploymentForMysql(mysql)
		if err := r.Delete(ctx, deployment); err != nil {
			return ctrl.Result{}, err
		}

		// Удаляем Service
		svc := r.serviceForMysql(mysql)
		if err := r.Delete(ctx, svc); err != nil {
			return ctrl.Result{}, err
		}

		// Удаляем PersistentVolumeClaim
		pvc := r.pvcForMysql(mysql)
		if err := r.Delete(ctx, pvc); err != nil {
			return ctrl.Result{}, err
		}

		// // Удаляем PersistentVolume
		// pv := r.pvForMysql(mysql)
		// if err := r.Delete(ctx, pv); err != nil {
		// 	return ctrl.Result{}, err
		// }

		// Возвращаем управление после удаления всех ресурсов
		return ctrl.Result{}, nil
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

	// Проверяем, если объект Service уже существует
	svc := r.serviceForMysql(mysql)
	foundSvc := &corev1.Service{}
	if err := r.Get(ctx, types.NamespacedName{Name: svc.Name, Namespace: svc.Namespace}, foundSvc); err != nil {
		if errors.IsNotFound(err) {
			// Если объект Service не найден, создаем его
			if err := r.Create(ctx, svc); err != nil {
				return ctrl.Result{}, err
			}
		} else {
			// Если произошла другая ошибка, возвращаем ошибку
			return ctrl.Result{}, err
		}
	}

	// // Проверяем, если объект PersistentVolume уже существует
	// pv := r.pvForMysql(mysql)
	// foundPv := &corev1.PersistentVolume{}
	// if err := r.Get(ctx, types.NamespacedName{Name: pv.Name}, foundPv); err != nil {
	// 	if errors.IsNotFound(err) {
	// 		// Если объект PersistentVolume не найден, создаем его
	// 		if err := r.Create(ctx, pv); err != nil {
	// 			return ctrl.Result{}, err
	// 		}
	// 	} else {
	// 		// Если произошла другая ошибка, возвращаем ошибку
	// 		return ctrl.Result{}, err
	// 	}
	// }

	// Проверяем, если объект PersistentVolumeClaim уже существует
	pvc := r.pvcForMysql(mysql)
	foundPvc := &corev1.PersistentVolumeClaim{}
	if err := r.Get(ctx, types.NamespacedName{Name: pvc.Name, Namespace: pvc.Namespace}, foundPvc); err != nil {
		if errors.IsNotFound(err) {
			// Если объект PersistentVolumeClaim не найден, создаем его
			if err := r.Create(ctx, pvc); err != nil {
				return ctrl.Result{}, err
			}
		} else {
			// Если произошла другая ошибка, возвращаем ошибку
			return ctrl.Result{}, err
		}
	}

	// Возвращаем управление, выходим из функции
	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *MySQLReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&mysqlv1.MySQL{}).
		Complete(r)
}

func (r *MySQLReconciler) serviceForMysql(cr *mysqlv1.MySQL) *corev1.Service {
	labels := map[string]string{
		"app":     cr.Name,
		"apptype": "mysql",
	}

	service := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cr.Name + "-service",
			Namespace: cr.Namespace,
		},
		Spec: corev1.ServiceSpec{
			Selector: labels,
			Ports: []corev1.ServicePort{
				{
					Name: "mysql",
					Port: 3306,
				},
			},
		},
	}

	// Set MySQL instance as the owner and controller
	if err := controllerutil.SetControllerReference(cr, service, r.Scheme); err != nil {
		return nil
	}
	return service
}

func (r *MySQLReconciler) pvcForMysql(cr *mysqlv1.MySQL) *corev1.PersistentVolumeClaim {
	labels := map[string]string{
		"app":     cr.Name,
		"apptype": "mysql",
	}

	crSpecStorage, err := resource.ParseQuantity(cr.Spec.Storage)
	if err != nil {
		return nil
	}

	pvc := &corev1.PersistentVolumeClaim{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cr.Name + "-pvc",
			Namespace: cr.Namespace,
			Labels:    labels,
		},
		Spec: corev1.PersistentVolumeClaimSpec{
			AccessModes: []corev1.PersistentVolumeAccessMode{
				"ReadWriteOnce",
			},
			Resources: corev1.VolumeResourceRequirements{
				Requests: corev1.ResourceList{
					corev1.ResourceStorage: crSpecStorage,
				},
			},
		},
	}

	// Set MySQL instance as the owner and controller
	if err := controllerutil.SetControllerReference(cr, pvc, r.Scheme); err != nil {
		return nil
	}
	return pvc
}

// func (r *MySQLReconciler) pvForMysql(cr *mysqlv1.MySQL) *corev1.PersistentVolume {

// 	labels := map[string]string{
// 		"app":     cr.Name,
// 		"apptype": "mysql",
// 	}

// 	crSpecStorage, err := resource.ParseQuantity(cr.Spec.Storage)
// 	if err != nil {
// 		return nil
// 	}

// 	pv := &corev1.PersistentVolume{
// 		ObjectMeta: metav1.ObjectMeta{
// 			Name:      cr.Name + "-pv",
// 			Namespace: cr.Namespace,
// 			Labels:    labels,
// 		},
// 		Spec: corev1.PersistentVolumeSpec{
// 			StorageClassName: cr.Spec.Name + "-storage-class",
// 			Capacity: corev1.ResourceList{
// 				corev1.ResourceStorage: crSpecStorage,
// 			},
// 			AccessModes: []corev1.PersistentVolumeAccessMode{
// 				"ReadWriteOnce",
// 			},
// 		},
// 	}

// 	return pv
// }

func (r *MySQLReconciler) deploymentForMysql(cr *mysqlv1.MySQL) *appsv1.Deployment {
	labels := map[string]string{
		"app":     cr.Name,
		"apptype": "mysql",
	}

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

	controllerutil.SetControllerReference(cr, deployment, r.Scheme)
	return deployment
}
