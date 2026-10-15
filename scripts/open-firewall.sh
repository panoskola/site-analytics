#!/usr/bin/env bash
# Oracle's Ubuntu images ship iptables rules that reject everything except SSH.
# This opens 80/443 on the VM itself (the OCI Security List must allow them too).
set -euo pipefail
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
sudo iptables -L INPUT -n --line-numbers | head -12
