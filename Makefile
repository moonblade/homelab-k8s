GITHUB_TOKEN:=$(shell cat secrets/github-pat)

bootstrap-git-sirius:
	flux bootstrap github --owner=moonblade --repository=homelab-k8s --branch=main --path=clusters/sirius/bootstrap

create-git-secret:
	kubectl create secret generic flux-system --namespace flux-system --from-literal=username=moonblade --from-literal=password=$(GITHUB_TOKEN)

kuztomize-flux-sirius:
	kubectl apply -k clusters/sirius/bootstrap/flux-system

secret-sealed:
	cat secrets/secret.yaml | kubeseal --format=yaml --cert secrets/kubeseal-public-key.pem > secret-sealed.yaml

