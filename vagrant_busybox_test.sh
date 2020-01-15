#show-labels



kubectl create -f /vagrant/vagrant_busybox_deploy.yaml &
watch -n 0.5 " figlet Deploy && kubectl get deploy && kubectl get rs && kubectl get pods -o wide"

watch "kubectl describe deployments"

cat /vagrant/vagrant_busybox_deploy.yaml|sed "s/replicas: 10/replicas: 3/" | kubectl apply -f - &
watch -n 0.5 "figlet Reduce && kubectl get deploy && kubectl get rs && kubectl get pods -o wide"

cat /vagrant/vagrant_busybox_deploy.yaml|sed "s/replicas: 10/replicas: 25/" | kubectl apply -f - &
watch -n 0.5 "figlet Add New && kubectl get deploy && kubectl get rs && kubectl get pods -o wide"

kubectl set image deployment.v1.apps/busybox-deployment busybox=busybox:1.29.3 --record &
watch -n 0.5 "figlet Update && kubectl get deploy && kubectl get rs && kubectl get pods -o wide"

figlet CLEANING
kubectl delete -f /vagrant/vagrant_busybox_deploy.yaml --force --grace-period=3
watch -n 0.5 "figlet Cleaning && kubectl get deploy && kubectl get rs && kubectl get pods -o wide"
