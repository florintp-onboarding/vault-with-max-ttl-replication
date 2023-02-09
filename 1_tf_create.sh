#!/bin/bash
# Generate the terraform scenario for generating 2 tokens in 2 different namespaces

vtemp1=$1
[ "Z$vtemp1" == "Z" ] && export TMPDIR=/tmp/tf

vtemp2=$2
if [ "Z$vtemp1" == "Z" ] ; then
	echo "No VAULT_TOKEN provided."
	exit 1
fi

cd $TMPDIR/tf
#Generate the terrform code
cat << EOFT2 > provider.tf
provider "vault" {
address = "http://127.0.0.1:8200/"
token = var.token
}
EOFT2

cat << EOFT3 > main.tf
# Creating Namespaces token
resource "vault_token" "namespace_token" {
  #role_name = "app"
  count     = length(var.namespace_name)
  namespace = var.namespace_name[count.index]
  policies  = var.policies
  display_name = var.namespace_name[count.index]
  ttl       = "720h"
}

output "generated_tokens" {
 value  =[for i,token in vault_token.namespace_token: format("id%s: %s",i, token.id)]
 description = "id"
}

EOFT3

cat << EOFT4 > terraform.tfvars
namespace_name = ["test3", "test4"]
policies       = ["admin", "default"]
EOFT4

#variables.tf
cat << EOFT5 > variables.tf
variable "token" {
  type        = string
  default     = "$VAULT_TOKEN"
  description = "Vault Token"
}

variable "vault_version" {
  type        = string
  default     = "3.5.0"
  description = "Vault version"
}

variable "namespace_name" {
  type        = list(any)
  default     = ["testa"]
  description = "namespace_name"
}

variable "policies" {
  type        = list(any)
  default     = ["read-only"]
  description = ""
}
EOFT5
terraform init
terraform fmt

