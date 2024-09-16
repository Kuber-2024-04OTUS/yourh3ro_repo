## ДЗ#13 Диагностика и отладка в Kubernetes

### Задания:
- Данное задание можно выполнять как в minikube так и в managed k8s в Yandex cloud
- Создайте манифест, описывающий pod с distroless образом для создания контейнера, например kyos0109/nginx-distroless и примените его в кластере. Приложите манифест к результатам ДЗ.
- С помощью команды kubectl debug создайте эфемерный контейнер для отладки этого пода. Отладочный контейнер должен иметь доступ к пространству имен pid для основного контейнера пода.
- Получите доступ к файловой системе отлаживаемого контейнера из эфемерного. Приложите к результатам ДЗ вывод команды ls –la для директории /etc/nginx
- Запустите в отладочном контейнере команду tcpdump -nn -i any -e port 80 (или другой порт, если у вас приложение на нем)
- Выполните несколько сетевых обращений к nginx в отлаживаемом поде любым удобным вам способом. Убедитесь что tcpdump отображает сетевые пакеты этих подключений. Приложите результат работы tcpdump к результатам ДЗ.
- С помощью kubectl debug создайте отладочный под для ноды, на которой запущен ваш под с distroless nginx
- Получите доступ к файловой системе ноды, и затем доступ к логам пода с distrolles nginx. Приложите сами логи, и команду их получения к результатам ДЗ.

#### Задание со *
- Выполните команду strace для корневого процесса nginx в рассматриваемом ранее поде. Опишите в результатах ДЗ какие операции необходимо сделать, для успешного выполнения команды, и также приложите ее вывод к результатам ДЗ.
### Описание решения
Сделал под с distroless nginx в namespace debug:
```
kubectl create namespace debug
kubectl apply -f nginx-distroless-pod.yaml
kubectl get pods --namespace debug
```
Далее с помощью команды kubectl debug подключился с базовым image busybox:1.36.0: 
Опция target дает возможность видеть pid и fs целевого контейнера:
```sh
kubectl debug -it --namespace debug --image busybox:1.36.0 --target websrv websrv -- sh

/ # ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
    7 101       0:00 nginx: worker process
   38 root      0:00 sh
   48 root      0:00 ps aux

## К fs получаю доступ по pid процесса по пути /proc/<pid>/root/
/ # ls -alh /proc/1/root/etc/nginx
total 48K
drwxr-xr-x    3 root     root        4.0K Oct  5  2020 .
drwxr-xr-x    1 root     root        4.0K Sep 16 17:08 ..
drwxr-xr-x    2 root     root        4.0K Oct  5  2020 conf.d
-rw-r--r--    1 root     root        1007 Apr 21  2020 fastcgi_params
-rw-r--r--    1 root     root        2.8K Apr 21  2020 koi-utf
-rw-r--r--    1 root     root        2.2K Apr 21  2020 koi-win
-rw-r--r--    1 root     root        5.1K Apr 21  2020 mime.types
lrwxrwxrwx    1 root     root          22 Apr 21  2020 modules -> /usr/lib/nginx/modules
-rw-r--r--    1 root     root         643 Apr 21  2020 nginx.conf
-rw-r--r--    1 root     root         636 Apr 21  2020 scgi_params
-rw-r--r--    1 root     root         664 Apr 21  2020 uwsgi_params
-rw-r--r--    1 root     root        3.5K Apr 21  2020 win-utf
```
Утилиты tcpdump нет в busybox, по этому в соседнем терминале поднимаю еще один контейнер с tcpdump:
```sh
kubectl debug -it --namespace debug --image corfr/tcpdump --target websrv websrv -- sh
```
```sh
## Делаю запрос на localhost:80 (nginx) из контейнера с busybox
/ # wget localhost:80
Connecting to localhost:80 (127.0.0.1:80)
saving to 'index.html'
index.html           100% |************************************************************************|   612  0:00:00 ETA
'index.html' saved
```
В контейнере с tcpdump вижу трафик:
```sh
/ # tcpdump -nn -i any -e port 80
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
17:59:52.410416  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 76: 127.0.0.1.50552 > 127.0.0.1.80: Flags [S], seq 2214484108, win 65495, options [mss 65495,sackOK,TS val 2054846209 ecr 0,nop,wscale 7], length 0
17:59:52.410424  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 76: 127.0.0.1.80 > 127.0.0.1.50552: Flags [S.], seq 1292859202, ack 2214484109, win 65483, options [mss 65495,sackOK,TS val 2054846209 ecr 2054846209,nop,wscale 7], length 0
17:59:52.410431  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 68: 127.0.0.1.50552 > 127.0.0.1.80: Flags [.], ack 1, win 512, options [nop,nop,TS val 2054846209 ecr 2054846209], length 0
17:59:52.410476  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 143: 127.0.0.1.50552 > 127.0.0.1.80: Flags [P.], seq 1:76, ack 1, win 512, options [nop,nop,TS val 2054846209 ecr 2054846209], length 75: HTTP: GET / HTTP/1.1
17:59:52.412200  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 301: 127.0.0.1.80 > 127.0.0.1.50552: Flags [P.], seq 1:234, ack 76, win 512, options [nop,nop,TS val 2054846211 ecr 2054846209], length 233: HTTP: HTTP/1.1 200 OK
17:59:52.412236  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 68: 127.0.0.1.50552 > 127.0.0.1.80: Flags [.], ack 234, win 511, options [nop,nop,TS val 2054846211 ecr 2054846211], length 0
17:59:52.412619  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 680: 127.0.0.1.80 > 127.0.0.1.50552: Flags [P.], seq 234:846, ack 76, win 512, options [nop,nop,TS val 2054846211 ecr 2054846211], length 612: HTTP
17:59:52.412655  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 68: 127.0.0.1.50552 > 127.0.0.1.80: Flags [.], ack 846, win 507, options [nop,nop,TS val 2054846211 ecr 2054846211], length 0
17:59:52.412802  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 68: 127.0.0.1.50552 > 127.0.0.1.80: Flags [F.], seq 76, ack 846, win 512, options [nop,nop,TS val 2054846211 ecr 2054846211], length 0
17:59:52.413573  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 68: 127.0.0.1.80 > 127.0.0.1.50552: Flags [F.], seq 846, ack 77, win 512, options [nop,nop,TS val 2054846212 ecr 2054846211], length 0
17:59:52.413588  In 00:00:00:00:00:00 ethertype IPv4 (0x0800), length 68: 127.0.0.1.50552 > 127.0.0.1.80: Flags [.], ack 847, win 512, options [nop,nop,TS val 2054846212 ecr 2054846212], length 0
11 packets captured
24 packets received by filter
2 packets dropped by kernel
```

Создаю debug container для ноды с тем же busybox:1.36.0
```sh
urhero@urheroComp:~/otus/homework13/yourh3ro_repo/kubernetes-debug$ kubectl get nodes
NAME             STATUS   ROLES           AGE   VERSION
docker-desktop   Ready    control-plane   98d   v1.29.2
urhero@urheroComp:~/otus/homework13/yourh3ro_repo/kubernetes-debug$ kubectl debug node/docker-desktop -it --image busybox:1.36.0
```
Получаю доступ в fs на ноде по пути /host/*. Нахожу логи nginx, где виден запрос, который отправлял wget-ом
```sh
/ # ls -al /host/var/log/pods/debug_websrv_4eff84d4-3c26-4232-a583-9cc6c428ef5e/websrv/0.log
lrwxrwxrwx    1 root     root           165 Sep 16 17:08 /host/var/log/pods/debug_websrv_4eff84d4-3c26-4232-a583-9cc6c428ef5e/websrv/0.log -> /var/lib/docker/containers/92404e00c71f6bc3fa8db36f6e5f019c602e0dcc68f5c6d72cb183470439153e/92404e00c71f6bc3fa8db36f6e5f019c602e0dcc68f5c6d72cb183470439153e-json.log

/ # cat /host/var/lib/docker/containers/92404e00c71f6bc3fa8db36f6e5f019c602e0dcc68f5c6d72cb183470439153e/92404e00c71f6bc3fa8db36f6e5f019c602e0dcc68f5c6d72cb183470439153e-json.log
{"log":"127.0.0.1 - - [17/Sep/2024:01:59:52 +0800] \"GET / HTTP/1.1\" 200 612 \"-\" \"Wget\" \"-\"\n","stream":"stdout","time":"2024-09-16T17:59:52.41380443Z"}
```
Что бы запускать strace внутри debug контейнера, нужно добавить опцию --profile general
```sh
## Запускаю debug контейнер с опцией --profile general
kubectl debug -it --profile general --namespace debug --image tachang/strace --target websrv websrv -- sh
/ # ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
    7 101       0:00 nginx: worker process
   73 root      0:00 sh
   79 root      0:00 ps aux

## Подключаюсь к nginx worker на pid 7, в это время в соседнем терминале делаю запрос wget на localhost:80
/ # strace -p 7
strace: Process 7 attached
epoll_wait(8, [{EPOLLIN, {u32=671604752, u64=140506231726096}}], 512, -1) = 1
accept4(6, {sa_family=AF_INET, sin_port=htons(41556), sin_addr=inet_addr("127.0.0.1")}, [112->16], SOCK_NONBLOCK) = 3
epoll_ctl(8, EPOLL_CTL_ADD, 3, {EPOLLIN|EPOLLRDHUP|EPOLLET, {u32=671605216, u64=140506231726560}}) = 0
epoll_wait(8, [{EPOLLIN, {u32=671605216, u64=140506231726560}}], 512, 60000) = 1
recvfrom(3, "GET / HTTP/1.1\r\nHost: localhost:"..., 1024, 0, NULL, NULL) = 75
stat("/usr/share/nginx/html/index.html", {st_mode=S_IFREG|0644, st_size=612, ...}) = 0
openat(AT_FDCWD, "/usr/share/nginx/html/index.html", O_RDONLY|O_NONBLOCK) = 11
fstat(11, {st_mode=S_IFREG|0644, st_size=612, ...}) = 0
writev(3, [{iov_base="HTTP/1.1 200 OK\r\nServer: nginx/1"..., iov_len=233}], 1) = 233
sendfile(3, 11, [0] => [612], 612)      = 612
write(5, "127.0.0.1 - - [17/Sep/2024:02:27"..., 83) = 83
close(11)                               = 0
close(3)                                = 0
epoll_wait(8,
```

В соседнем терминале делаю запрос на nginx, в то время как strace подключен к процессу:
```sh
urhero@urheroComp:~$ kubectl debug -it --namespace debug --image busybox:1.36.0 --target websrv websrv -- wget -S localhost:80
Targeting container "websrv". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-vjqsz.
Connecting to localhost:80 (127.0.0.1:80)
  HTTP/1.1 200 OK
  Server: nginx/1.18.0
  Date: Mon, 16 Sep 2024 18:27:07 GMT
  Content-Type: text/html
  Content-Length: 612
  Last-Modified: Tue, 21 Apr 2020 12:43:12 GMT
  Connection: close
  ETag: "5e9eea60-264"
  Accept-Ranges: bytes

saving to 'index.html'
index.html           100% |********************************|   612  0:00:00 ETA
'index.html' saved
```