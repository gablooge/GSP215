#!/bin/bash

gcloud beta compute instances create siege-vm --zone=us-west1-c --machine-type=n1-standard-1 --metadata startup-script='#! /bin/bash
sudo su -
sudo apt-get -y install siege'

export EXTERNAL_IP=$(gcloud compute instances list --filter="NAME=siege-vm" | awk 'BEGIN { cnt=0; } { cnt+=1; if (cnt > 1) print $5; }')

gcloud compute security-policies create denylist-siege

gcloud compute security-policies rules create 1000 --action='deny-403' --security-policy=denylist-siege --src-ip-ranges=$EXTERNAL_IP

gcloud compute security-policies rules create 1001 --action=allow --security-policy=denylist-siege --description="Default rule, higher priority overrides it" --src-ip-ranges=\*

# gcloud compute backend-services update http-backend --security-policy=denylist-siege

