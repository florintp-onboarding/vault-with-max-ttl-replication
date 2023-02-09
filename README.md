[![license](http://img.shields.io/badge/license-apache_2.0-red.svg?style=flat)](https://github.com/florintp-onboarding/vaultwith-max-ttl-replication/blob/main/LICENSE)


# Running a Vault with Raft storage backend on localhost having the SOFTHSM2 as auto-unseal mechanism

The repository is used for creating a test Vault+Raft Integrated storage playground for testing the max-ttl global configuration.
The script is written in Bash and was successfully tested on Ubuntu (VERSION="22.04.1 LTS (Jammy Jellyfish)".


# Prerequisites
Install the latest version of vault-enterprise and bash for your (*debian) distribution.
By detauls

# How to create the configuration and checking the TTL value

- Clone the current repository 
```
git clone https://github.com/florintp-onboarding/vault-with-max-ttl-replication
```
or
```
gh repo clone florintp-onboarding/vault-with-max-ttl-replication
```
- Save a valid enterprise license file into:
"/etc/vault.d/vault.hclic"
or
"./vault.hclic"

- Change the permissions for the shell scripts
chmod +rx *.sh


- Execute the script for observing the max-ttl for 2 specific TOKENS generated into 2 different namespaces
bash steps_to_reproduce.sh


