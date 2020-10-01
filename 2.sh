#!/bin/bash

while [[ -z "$(gcloud config get-value core/account)" ]]; 
do echo "waiting login" && sleep 2; 
done

while [[ -z "$(gcloud config get-value project)" ]]; 
do echo "waiting project" && sleep 2; 
done

export PROJECT_ID=$(gcloud info --format='value(config.project)')

gcloud beta compute instance-templates create europe-west1-template --machine-type=n1-standard-1 --subnet=projects/$PROJECT_ID/regions/europe-west1/subnetworks/default --network-tier=PREMIUM --metadata=startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh --maintenance-policy=MIGRATE --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --region=europe-west1 --tags=http-server --image=debian-10-buster-v20200805 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=europe-west1-template --no-shielded-secure-boot --no-shielded-vtpm --no-shielded-integrity-monitoring --reservation-affinity=any

gcloud beta compute instance-groups managed create europe-west1-mig --base-instance-name=europe-west1-mig --template=europe-west1-template --size=1 --zones=europe-west1-b,europe-west1-c,europe-west1-d --instance-redistribution-type=PROACTIVE

gcloud beta compute instance-groups managed set-autoscaling "europe-west1-mig" --region "europe-west1" --cool-down-period "45" --max-num-replicas "5" --min-num-replicas "1" --target-cpu-utilization "0.8" --mode "on"

