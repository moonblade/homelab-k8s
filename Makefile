bootstrap-git-sirius:
	flux bootstrap github --owner=moonblade --repository=homelab-k8s --branch=main --path=clusters/sirius/bootstrap

kuztomize-flux-sirius:
	kubectl apply -k clusters/sirius/bootstrap/flux-system

