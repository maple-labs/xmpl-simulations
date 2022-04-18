#!/usr/bin/env bash
set -e

while getopts p:t: flag
do
    case "${flag}" in
        p) profile=${OPTARG};;
        t) test=${OPTARG};;
    esac
done

export FOUNDRY_PROFILE=$profile
echo Using profile: $FOUNDRY_PROFILE

if [ -z "$test" ];
then
    forge test --match-path "tests/*" --rpc-url "$ETH_RPC_URL" --ffi
else
    forge test --match "$test" --rpc-url "$ETH_RPC_URL" --ffi
fi
