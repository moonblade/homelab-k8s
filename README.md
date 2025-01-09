# Homelab Kubernetes Cluster Manifests


Be able to setup kubernetes entirely from manifests.
`make bootstrap-git-sirius` can be used to setup the git repo for the very first time. Its no longer needed after that its easier to do `make kuztomize-flux-sirius`.

Once thats done it looks for any changes in `clusters/sirius/bootstap` folder, so anything that needs to be added needs to have the stub added here.

## Initial setup of cluster

```bash
make kuztomize-flux-sirius
make create-git-secret
make create-sealed-secret-key
sleep 5
make kuztomize-flux-sirius

```


## Logs

- Jan 9, 2025

After fighting with cilium for a long while and getting entire cluster evaporated whenever I try to get cilium to work, gave up for now and disabled cilium. Will come back to cilium when I have more time to debug it.
I'm trying to get ingress to work now. Got ingress class to be default. Now need to make ingress automatically give certificates.

- Jan 8, 2025

Sigh, had to setup clsuter again. so need to make sure to put down the steps to do it properly from scratch.

After banging my head against the wall to make homer work with helm chart, the values were only possible in line, which I did not want, I wanted it to come from a differnet config.yaml file. Eventually just gave up and used jd's method of deploy and svc instead and creating the config with kustomize.

I have no clue how certmanager or clusterissuer works, I've used it and its always been magic to me, right now I'm stealing code from jd to connect clusterissuer to cloudflare to get certs and dns from there and magically have ingress work? no clue. will see what happens. How does letsencrypt and cloudflare interact? no clue. I need to read up on it.

- Jan 7 2025

No git repo's were being observed, so added `gotk-sync.yaml` which adds bootstrap folder to flux to keep track of, anything further can be tracked with that.
Accidentally created sealed secrets with command line and had to do a bit of work to remove it, since flux was recreating it again, and couldnt' figure out flux delete command immediately. Chatgpt led me wrong a couple times.
Tried setting up external-dns to test, but it needed dependancies and I didn't get sealed secrets working. So instead tried with nginx app, and that wasn't showing up, realized it went to a different namespace. Happy that apps and monitoring was working need to setup infrastructure stuff now.
Added git pat as secret and added it to makefile. Since sealed secrets wasn't coming up again, made a dummy change to push and that fixed it. External dns should work now even if nothing is configured on it.

Saved kubeseal private and public keys in secret, public doesn't necessarily need to be in it, but eh better safe than sorry.

Added dns endpoints, but doesn't seem to be updating online, will need to check tomorrow to see why

- Jan 6 2025

Setup gotk-components.yaml, didn't connect it to cluster yet, or rather, it wasn't working because ip was wrong. Fixed ip on nixos config and restarted to fix cluster then this started working.
