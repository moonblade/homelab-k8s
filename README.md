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

## Homer

Dashboard for everything on the cluster. Available here [Homer](homer.sirius.moonblade.work)

## Transmission

Transmission for downloading my audiobooks. Available here [Transmission](transmission.sirius.moonblade.work)

## Logs

- Jan 6, 2025  

Setup gotk-components.yaml, didn't connect it to cluster yet, or rather, it wasn't working because IP was wrong. Fixed IP on NixOS config and restarted to fix cluster, then this started working.

- Jan 7, 2025  

No git repos were being observed, so added `gotk-sync.yaml` which adds the bootstrap folder to Flux to keep track of. Anything further can be tracked with that.  
Accidentally created sealed secrets with command line and had to do a bit of work to remove it since Flux was recreating it again, and I couldn't figure out the Flux delete command immediately. ChatGPT led me wrong a couple of times.  

Tried setting up external-dns to test, but it needed dependencies, and I didn't get sealed secrets working. So instead, I tried with the nginx app, and that wasn't showing up. Realized it went to a different namespace.  

Happy that apps and monitoring were working—need to set up infrastructure stuff now.  
Added Git PAT as a secret and included it in the Makefile. Since sealed secrets weren't coming up again, I made a dummy change to push, and that fixed it. External DNS should work now even if nothing is configured on it.  

Saved kubeseal private and public keys in secret. The public key doesn't necessarily need to be in it, but better safe than sorry.  

Added DNS endpoints, but they don't seem to be updating online. Will need to check tomorrow to see why.

- Jan 8, 2025  

Sigh. Had to set up the cluster again, so I need to make sure to put down the steps to do it properly from scratch.  

After banging my head against the wall to make Homer work with the Helm chart, I realized the values were only possible inline, which I didn't want—I wanted them to come from a different `config.yaml` file. Eventually, I just gave up and used JD's method of deploy and service instead, creating the config with Kustomize.  

I have no clue how CertManager or ClusterIssuer works. I've used it, and it's always been magic to me. Right now, I'm stealing code from JD to connect ClusterIssuer to Cloudflare to get certs and DNS from there and magically have ingress work? No clue. Will see what happens.  

How do Let's Encrypt and Cloudflare interact? No clue. I need to read up on it.

- Jan 9, 2025  

After fighting with Cilium for a long while and having the entire cluster evaporate whenever I tried to get Cilium to work, I gave up for now and disabled Cilium. Will come back to it when I have more time to debug.  

I'm trying to get ingress to work now. Got the ingress class to be default. Now need to make ingress automatically give certificates.  

Note to self: When stealing code, READ THROUGH THE CODE to ensure your values are correct.  

Any external-dns was using the wrong filter, so it pretty much didn't care about any of my ingresses. It wasn't creating anything. Now it's fixed, and tada! My entries are auto-added in Cloudflare directly. Neat.  

Adding DNS entries for Athena and Sirius (Proxmox VM and the NixOS VM with K3s on it, so that I'll be able to use `kubectl` commands outside) in `./clusters/sirius/infra/external-dns/dnsendpoints.yaml`.

- Jan 10, 2025  

Added Homer items for the things that already exist. Cert Manager is still not proper. Will need to debug it today, hopefully.  

Finally starting on moving stuff from the Raspberry Pi to here. Starting with Transmission.  
Now that I have NFS access to the connected drive from Proxmox to the cluster, I can download stuff.

- Jan 11, 2025  

Since drives are messed up, I'm trying out Transmission and Flux on Athena without any external drives.  
Will try and write a sorter for it if possible. Nope file permissions are a bitch, they kicked my ass up and down the curb, so I gave up on it for now.
Will need to retry with long horn, hopefully that allows sharing.

- Jan 13, 2025

Got new hard disk setup, so gonna try to use longhorn to use it to provision storage for everything else. Setup longhorn infra.

- Jan 15, 2025

I'm remote and either the drive died or its no longer connected. Well crap.

So pivoted to fixing certmanager cert instead. Reinstalling certmanager got me challenges crd, which wasn't present earlier, but the challenge was pending.
Apparently token got revoked? so created a new token and gave that to cluster issuer then it was still pending because challenge wasn't completed because it was trying with ipv6 and getting permission denied.
Exasperated ended up setting ipv6 off in nixos instead. That solved cert side but now site wasn't loading. Sigh.
Rebooted machine and now it seems to be working

- Jan 23, 2025

Spent a long time and make ipv6 work on both athena and sirius nixos. Having a few false starts and a few network freeze outs, but got there in the end. And it didn't help with the challenges problem at all. So thats still unsolved.

I was unable to access homer, then realized it was because I had an /etc/hosts entry for homer, that was why it wasn't working. Removed it and it started working fine. Sigh.

- Jan 24, 2025

Setup *Weave* to have some visibility into the cluster, had some issues with setting password, but reboot got it working. :shrug:

Made a script to auto connect or disconnect hard disk based on its avialability, so now it should work at least when its avaialable. Will see what happens if not. Transmission works now with hostpath instead.



