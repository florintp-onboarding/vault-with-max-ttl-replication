#!/bin/bash
# Generate the terraform scenario

vtemp1=$1
[ "Z$vtemp1" == "Z" ] && export TMPDIR=/tmp/tf

vtemp2=$2
if [ "Z$vtemp1" == "Z" ] ; then
	echo "No VAULT_TOKEN provided."
	exit 1
fi

#Helperfor running Vault
function vault1 {
    (export VAULT_ADDR=http://127.0.0.1:8200 && $TMPDIR/vault "$@")
}

cd $TMPDIR/tf
terraform apply --auto-approve
echo "####"
for token in $(terraform output -json|jq -r '.generated_tokens.value[]'|awk '{print $NF}') ; do
	echo "####"
	echo "TOKEN lookup for $token"
	vault1 token lookup -accessor $token
done
