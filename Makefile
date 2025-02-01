GITHUB_TOKEN:=$(shell cat secrets/github-pat)

bootstrap-git-sirius:
	flux bootstrap github --owner=moonblade --repository=homelab-k8s --branch=main --path=clusters/sirius/bootstrap

create-git-secret:
	kubectl create secret generic flux-system --namespace flux-system --from-literal=username=moonblade --from-literal=password=$(GITHUB_TOKEN)

kuztomize-flux-sirius:
	kubectl apply -k clusters/sirius/bootstrap/flux-system

create-sealed-secret-key:
	kubectl -n flux-system create secret tls sealed-secrets-key --cert ./secrets/kubeseal-public-key.crt --key ./secrets/kubeseal-private-key.key

secret-sealed:
	# cat secrets/secret.yaml | kubeseal --format=yaml --cert secrets/kubeseal-public-key.crt > secret-sealed.yaml
	# cat secrets/secret.yaml | kubeseal --controller-name=sealed-secrets --controller-namespace=flux-system -o yaml
	cat secrets/secret.yaml | kubeseal

dashboard-token:
	@kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath="{.data.token}" | base64 -d

cilium:
	cilium install --set cluster.name=sirius --set operator.replicas=1 --set ipam.mode=kubernetes --set operator.clusterPoolIPv4PodCIDRList="10.42.0.0/16" --set k8sServiceHost=192.168.1.150 --set k8sServicePort=6443
