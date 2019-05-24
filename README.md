# flux-bug-test-repo

* Clone this repo
* vim scripts/flux.sh and change the repo / branch 
* run ./scripts/start-kind.sh
* run ./scripts/flux.sh
* grab the identity key and add to your cloned repo 
* wait for flux to apply the Configmap
* Check that the configmap is missing the _sync-checksum_ annotaation and the Warning message appear in the flux log
```
flux-7965b4c4dc-wwcqz flux ts=2019-05-24T12:07:41.615700947Z caller=sync.go:150 component=cluster warning="resource to be synced has not been updated; skipping" resource=vault:configmap/vault-auth-jwt
```
