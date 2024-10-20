`helm install harbor harbor/harbor --create-namespace --namespace harbor -f values.yaml`

У меня не запустилось с первого раза, ругалось на то что не смогло выполнить все миграции 
```
error: ... Dirty database version 5 ...
```
Руками почистил pv, pvc, ребутнул postgres а потом harbor core, все отработало корректно