# farm-association-gitops

Репозиторій конфігурації (GitOps) для застосунку [Farm-association](https://github.com/Brenkach/Farm-association). Бажаний стан кластера описано тут, а Argo CD у кластері сам приводить кластер до цього стану.

## Структура

```
bootstrap/root-app.yaml          # кореневий Application (App of Apps), застосовується вручну один раз
argocd-apps/farm-association.yaml   # Application для чарта застосунку
charts/farm-association/         # Helm-чарт з ЛР-4
  values.yaml                    # значення за замовчуванням
  values-minikube.yaml           # значення для кластера minikube
```

## Секрети

Паролі в Git не зберігаються. Чарт підтримує `secret.existingSecret`: для minikube Secret `farm-secret` створюється в кластері один раз вручну, а чарт лише посилається на нього.

```bash
kubectl create namespace farm
kubectl create secret generic farm-secret -n farm \
  --from-literal=PG_PASSWORD='<пароль>' \
  --from-literal=SECRET_KEY='<ключ>'
```

## Розгортання з нуля

```bash
# 1. Argo CD
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Secret застосунку (див. вище)

# 3. Кореневий Application — єдиний об'єкт, що застосовується вручну
kubectl apply -n argocd -f bootstrap/root-app.yaml
```

Далі Argo CD сам створює Application `farm-association` з каталогу `argocd-apps/` і розгортає чарт у namespace `farm`.

## Випуск нової версії

Змінити `image.tag` у `charts/farm-association/values-minikube.yaml`, зробити commit і push. Argo CD помітить зміну (за замовчуванням перевіряє репозиторій кожні 3 хвилини) і перерозгорне застосунок.
