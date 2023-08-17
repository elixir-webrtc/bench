#!/bin/bash
curl -X POST "https://videoroom5.membrane.ovh/?service=turn&username=johnsmith"| jq -r '. | .username + "=" + .password'
#username=$(jq ".username .password" $ret)
#password=$(jq '.password' $ret)
#echo "$username=$password"
