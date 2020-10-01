#!/bin/bash

while [[ -z "$(gcloud config get-value core/account)" ]]; 
do echo "waiting login" && sleep 2; 
done

while [[ -z "$(gcloud config get-value project)" ]]; 
do echo "waiting project" && sleep 2; 
done

gcloud compute firewall-rules create "default-allow-http" --network=default --target-tags=http-server --allow=tcp:80 --source-ranges="0.0.0.0/0" --description="Narrowing HTTP traffic"

gcloud compute firewall-rules create "default-allow-health-check" --network=default --target-tags=http-server --allow=tcp --source-ranges="130.211.0.0/22,35.191.0.0/16" --description="Narrowing HTTP traffic"

export PROJECT_ID=$(gcloud info --format='value(config.project)')

gcloud beta compute instance-templates create us-east1-template --machine-type=n1-standard-1 --subnet=projects/$PROJECT_ID/regions/us-east1/subnetworks/default --network-tier=PREMIUM --metadata=startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh --maintenance-policy=MIGRATE --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --region=us-east1 --tags=http-server --image=debian-10-buster-v20200805 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=us-east1-template --no-shielded-secure-boot --no-shielded-vtpm --no-shielded-integrity-monitoring --reservation-affinity=any

gcloud beta compute instance-groups managed create us-east1-mig --base-instance-name=us-east1-mig --template=us-east1-template --size=1 --zones=us-east1-b,us-east1-c,us-east1-d --instance-redistribution-type=PROACTIVE

gcloud beta compute instance-groups managed set-autoscaling "us-east1-mig" --region "us-east1" --cool-down-period "45" --max-num-replicas "5" --min-num-replicas "1" --target-cpu-utilization "0.8" --mode "on"


gcloud beta compute instance-templates create europe-west1-template --machine-type=n1-standard-1 --subnet=projects/$PROJECT_ID/regions/europe-west1/subnetworks/default --network-tier=PREMIUM --metadata=startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh --maintenance-policy=MIGRATE --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --region=europe-west1 --tags=http-server --image=debian-10-buster-v20200805 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=europe-west1-template --no-shielded-secure-boot --no-shielded-vtpm --no-shielded-integrity-monitoring --reservation-affinity=any

gcloud beta compute instance-groups managed create europe-west1-mig --base-instance-name=europe-west1-mig --template=europe-west1-template --size=1 --zones=europe-west1-b,europe-west1-c,europe-west1-d --instance-redistribution-type=PROACTIVE

gcloud beta compute instance-groups managed set-autoscaling "europe-west1-mig" --region "europe-west1" --cool-down-period "45" --max-num-replicas "5" --min-num-replicas "1" --target-cpu-utilization "0.8" --mode "on"



gcloud beta compute health-checks create tcp http-health-check --port=80 --proxy-header=NONE --no-enable-logging --check-interval=5 --timeout=5 --unhealthy-threshold=2 --healthy-threshold=2

gcloud compute instance-groups managed set-named-ports us-east1-mig --named-ports http:80 --region us-east1 

gcloud compute instance-groups managed set-named-ports europe-west1-mig --named-ports http:80 --region europe-west1 

gcloud compute backend-services create http-backend --protocol HTTP --health-checks http-health-check --global 

gcloud compute backend-services add-backend http-backend --instance-group us-east1-mig --instance-group-region us-east1 --balancing-mode RATE --max-rate-per-instance 50 --capacity-scaler 1.0 --global 

gcloud compute backend-services add-backend http-backend --instance-group europe-west1-mig --instance-group-region europe-west1 --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1.0 --global 

gcloud compute url-maps create http-lb --default-service http-backend 

gcloud compute target-http-proxies create http-lb-proxy --url-map http-lb 

gcloud compute forwarding-rules create http-ipv4-rule --global --target-http-proxy http-lb-proxy --ports 80 --ip-version IPV4 

gcloud compute forwarding-rules create http-ipv6-rule --global --target-http-proxy http-lb-proxy --ports 80 --ip-version IPV6 

gcloud compute forwarding-rules list


# gcloud beta compute instances create siege-vm --zone=us-west1-c --machine-type=n1-standard-1 --metadata startup-script='#! /bin/bash
# sudo su -
# sudo apt-get -y install siege'

gcloud beta compute instances create siege-vm --zone=us-west1-c --machine-type=n1-standard-1

gcloud beta compute ssh --zone "us-west1-c" "siege-vm" --quiet --command="sudo apt-get -y install siege"


export EXTERNAL_IP=$(gcloud compute instances list --filter="NAME=siege-vm" | awk 'BEGIN { cnt=0; } { cnt+=1; if (cnt > 1) print $5; }')

gcloud compute security-policies create denylist-siege

gcloud compute security-policies rules create 1000 --action='deny-403' --security-policy=denylist-siege --src-ip-ranges=$EXTERNAL_IP

gcloud compute security-policies rules create 1001 --action=allow --security-policy=denylist-siege --description="Default rule, higher priority overrides it" --src-ip-ranges=\*

# gcloud compute backend-services update http-backend --security-policy=denylist-siege






