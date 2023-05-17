# virtual_machine

repo for describe virtual machine terraform and vagrant

При работе с терраформом в Яндекс облаке для авторизации:
```
$Env:YC_TOKEN=$(yc iam create-token)
$Env:YC_CLOUD_ID=$(yc config get cloud-id)
$Env:YC_FOLDER_ID=$(yc config get folder-id)
```

Получить доступ к кластеру:
```
yc managed-kubernetes cluster get-credentials terraform-cluster --external --force
```
