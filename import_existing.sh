#!/bin/bash
set -e
PROJECT_ID="shopware-terraform-tt"
REGION="europe-west3"
ZONE="europe-west3-c"

echo "Checking and importing existing resources if present..."

terraform import google_compute_network.shopware_network "projects/$PROJECT_ID/global/networks/shopware-network" || true
terraform import google_compute_firewall.shopware_firewall "projects/$PROJECT_ID/global/firewalls/shopware-firewall" || true
terraform import google_compute_address.shopware_ip "projects/$PROJECT_ID/regions/$REGION/addresses/shopware-ip" || true
terraform import google_service_account.shopware_sa "projects/$PROJECT_ID/serviceAccounts/shopware-vm-sa@$PROJECT_ID.iam.gserviceaccount.com" || true
terraform import google_secret_manager_secret.db_password "projects/$PROJECT_ID/secrets/shopware-db-password" || true
terraform import google_compute_instance.shopware_vm "projects/$PROJECT_ID/zones/$ZONE/instances/shopware-demo" || true

echo "Import completed successfully (missing ones will be created by Terraform)."
