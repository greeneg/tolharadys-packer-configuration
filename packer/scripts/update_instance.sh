#!/bin/bash

set -e

echo "Waiting on YaST session to complete. Please be patient...."
sleep 180
counter=0
while true; do
  if pgrep ruby 2>&1 >/dev/null || pgrep zypper; then
    sleep 5
  else
    zypper lr
    zypper --verbose ref
    zypper --verbose up -y --no-recommends
    counter=$(( ${counter} + 1 ))
    if [[ $counter -gt 1 ]]; then
      break
    fi
  fi
done
