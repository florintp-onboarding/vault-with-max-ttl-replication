#!/bin/bash
#
# This script is used for testing a Vault with autounseal SOFTHSM2 on Ubuntu (*debian) servers
#

set -eu

#Block Variables
export TMPDIR=/tmp/vault_XXX442
export VAULT_ADDR="http://127.0.0.1:8200"
export HSM_PIN=12345
export VAULT_SOURCE="" 
export VAULT_LICENSE_FILE=""
export LICENSES=("vault_license.hclic" "/etc/vault.d/vault.hclic" "vault.hclic")
export script_name="$(basename "$0")"


test -e /etc/os-release && os_release='/etc/os-release' || os_release='/usr/lib/os-release'
. "${os_release}"

if [ "${ID:-linux}" = "debian" ] || [ "${ID_LIKE#*debian*}" != "${ID_LIKE}" ]; then
    echo "Running on ${PRETTY_NAME:-Linux}"
    echo "Looks like Debian!"
else
    >&2 echo "Sorry, this script supports only *debian Linux operating systems."
    exit 1
fi

#Check the license availability
for i in "${LICENSES[@]}"; do
    test -e "$i" && export VAULT_LICENSE_FILE="$i" && echo $i
done

if [ "Z${VAULT_LICENSE_FILE}" == "Z" ] ; then
    >&2 echo "Sorry, this script requires a valid Vault license file /etc/vault.d/vault.hclic or as vault.hclic."
   exit 2
fi

#Helper for running Vault
function vault1 {
    (export VAULT_ADDR=http://127.0.0.1:8200 && $TMPDIR/vault "$@")
}

###
./cleanup.sh $TMPDIR

#Create default directory and update OS
mkdir -p $TMPDIR/data/raft
mkdir -p $TMPDIR/tf
sudo apt-get update
sudo apt-get install -y softhsm2 zip jq wget openssl opensc

#Get SOFTHSM libpaths
SOFTHSMLIB=""
SOFTLIBLOCS=("/usr/lib64/libsofthsm2.so" "/usr/local/lib/softhsm/libsofthsm2.so" "/usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so")
for i in "${SOFTLIBLOCS[@]}"; do
        if [ -f "$i" ]; then
             export SOFTHSMLIB="$i"
        fi
done

#Create HSM slots
export SLOT_NUM1=$(softhsm2-util --init-token --free --so-pin=$HSM_PIN --pin=$HSM_PIN --label="test-kms-root" | grep -oE '[0-9]+$')
export SLOT_NUM2=$(softhsm2-util --init-token --free --so-pin=$HSM_PIN --pin=$HSM_PIN --label="test-kms-int-ns1" | grep -oE '[0-9]+$')
export SLOT_NUM3=$(softhsm2-util --init-token --free --so-pin=$HSM_PIN --pin=$HSM_PIN --label="test-kms-int-ns2" | grep -oE '[0-9]+$')
export SLOT_NUM0=$(softhsm2-util --init-token --free --so-pin=$HSM_PIN --pin=$HSM_PIN --label="vault-hsm-key" | grep -oE '[0-9]+$')

#Download the new vault zip and infalting into temporary directory
#Default is ( cd $TMPDIR ; wget https://releases.hashicorp.com/vault/1.12.3+ent.hsm.fips1402/vault_1.12.3+ent.hsm.fips1402_linux_amd64.zip ; unzip vault_1.12.3+ent.hsm.fips1402_linux_amd64.zip)
if [ "Z$VAULT_SOURCE" == "Z" ] ; then
	export VAULT_SOURCE="https://releases.hashicorp.com/vault/1.12.3+ent.hsm.fips1402/vault_1.12.3+ent.hsm.fips1402_linux_amd64.zip"
fi
( cd $TMPDIR ; wget "${VAULT_SOURCE}"; unzip $(basename ${VAULT_SOURCE}) )

#Create default Vault config
cat << EOFT1 > $TMPDIR/config.hcl
ui = true
disable_mlock = true

storage "raft" {
  path = "$TMPDIR/data"
  node_id = "vault-1"
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"

# HTTP listener
listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = 1
}

kms_library "pkcs11" {
	name="softhsm"
	library="$SOFTHSMLIB"
}

license_path = "${VAULT_LICENSE_FILE}"
default_lease_ttl = "5m"
max_lease_ttl = "10m"

seal "pkcs11" {
lib            = "/usr/lib/softhsm/libsofthsm2.so"
slot           = "${SLOT_NUM0}"
pin            = "${HSM_PIN}"
key_label      = "vault-hsm-key"
hmac_key_label = "vault-hsm-hmac-key"
generate_key   = "true"
}
EOFT1

# Start Vault server
vault1 server -log-level=debug -config=$TMPDIR/config.hcl 2> $TMPDIR/vault.log &
while ! nc -w 1 -d localhost 8200; do sleep 1; done

vault1 operator init -format=json -recovery-shares=1 -recovery-threshold=1 > $TMPDIR/init.json

vault1 login $(jq -r .root_token < $TMPDIR/init.json)
# Setup a new namespace test3 and test4
export VAULT_TOKEN=$(jq -r .root_token < $TMPDIR/init.json)
vault1 namespace create test3
vault1 namespace create test4

# Example for max_lease_ttl
./1_tf_create.sh $TMPDIR $VAULT_TOKEN
./2_validation.sh $TMPDIR $VAULT_TOKEN
