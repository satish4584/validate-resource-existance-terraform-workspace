#! /usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
set +x
TOKEN=$(cat ~/.terraform.d/credentials.tfrc.json | jq -r '.credentials["app.terraform.io"].token')
ps=100
orgName="GLG"
FULLRES=""
cacheFileName="tfews_${orgName}"
set -u resource_exist
# Below Block gets the workspace space id by using the Terraform Workspace Rest Api.
if [[ ! -f $cacheFileName ]];then
  for pn in {1..5}
  do
    unset RES
    unset np
    uri="https://app.terraform.io/api/v2/organizations/${orgName}/workspaces?page%5Bnumber%5D=${pn}&page%5Bsize%5D=${ps}"
    RES=$(curl --header "Authorization: Bearer ${TOKEN}" --header "Content-Type: application/vnd.api+json" "${uri}")
    np=$(echo $RES | jq -r '.meta.pagination["next-page"]')
    THISRES=$(echo $RES | jq -r '.data[] | .attributes.name + "::" + .id')
    FULLRES="$FULLRES $THISRES"
    if [[ $np == null ]]; then
      echo "last page"
      break;
    fi
  done
  echo $FULLRES > $cacheFileName
fi
# Below Block will itrate through the each iteam in the workspace list.
# cat ws_name.txt | cut -d "|" -f 5 > workspace_list

while read ws_name
do
  echo $ws_name
  wsId=$(cat $cacheFileName |  grep -o -e "${ws_name}::*[a-zA-Z0-9-]*" | cut -d':' -f3)
  resources=$(curl   --header "Authorization: Bearer ${TOKEN}"   --header "Content-Type: application/vnd.api+json"   https://app.terraform.io/api/v2/workspaces/${wsId}/current-state-version)
  check_status=$(echo $resources | jq -r '.errors[0].status')
  echo $check_status
  if [[ $check_status == "404" ]]; then
    echo $ws_name >> final_list.txt
  else 
    resource_exist=$(echo $resources | jq  -r '.data.attributes.resources')
    resource_length=$(echo $resource_exist | jq length)
    echo $resource_length
    if [ $resource_length == 0 ]; then
      echo $ws_name >> final_list.txt
    else
      echo "Array non empty"
    fi
  fi
done <workspace_list



