clear

#!/bin/bash
# Define color variables

BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

# Array of color codes excluding black and white
TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
BG_COLORS=($BG_RED $BG_GREEN $BG_YELLOW $BG_BLUE $BG_MAGENTA $BG_CYAN)

# Pick random colors
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}
RANDOM_BG_COLOR=${BG_COLORS[$RANDOM % ${#BG_COLORS[@]}]}



# Step 1: Get the region information from gcloud
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

export INSTANCE_NAME=eval-instance

# Step 2: Wait for instance to become active
export INSTANCE_NAME=eval-instance; export ENV_NAME=eval; export PREV_INSTANCE_STATE=; while : ; do export INSTANCE_STATE=$(curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" -X GET "https://apigee.googleapis.com/v1/organizations/${GOOGLE_CLOUD_PROJECT}/instances/${INSTANCE_NAME}" | jq "select(.state != null) | .state" --raw-output); [[ "${INSTANCE_STATE}" == "${PREV_INSTANCE_STATE}" ]] || (echo; echo "INSTANCE_STATE=${INSTANCE_STATE}"); export PREV_INSTANCE_STATE=${INSTANCE_STATE}; [[ "${INSTANCE_STATE}" != "ACTIVE" ]] || break; echo -n "."; sleep 5; done; echo; echo "instance created, waiting for environment ${ENV_NAME} to be attached to instance"; while : ; do export ATTACHMENT_DONE=$(curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" -X GET "https://apigee.googleapis.com/v1/organizations/${GOOGLE_CLOUD_PROJECT}/instances/${INSTANCE_NAME}/attachments" | jq "select(.attachments != null) | .attachments[] | select(.environment == \"${ENV_NAME}\") | .environment" --join-output); [[ "${ATTACHMENT_DONE}" != "${ENV_NAME}" ]] || break; echo -n "."; sleep 5; done; echo "***ORG IS READY TO USE***";

# Step 3: Create the 'bank-readonly' configuration file
cat > bank-readonly.json <<EOF_END
{
  "name": "bank-readonly",
  "displayName": "bank (read-only)",
  "approvalType": "auto",
  "attributes": [
    {
      "name": "access",
      "value": "public"
    }
  ],
  "description": "allows read-only access to bank API",
  "environments": [
    "eval"
  ],
  "operationGroup": {
    "operationConfigs": [
      {
        "apiSource": "bank-v1",
        "operations": [
          {
            "resource": "/**",
            "methods": [
              "GET"
            ]
          }
        ],
        "quota": {}
      }
    ],
    "operationConfigType": "proxy"
  }
}
EOF_END

curl -X POST "https://apigee.googleapis.com/v1/organizations/$DEVSHELL_PROJECT_ID/apiproducts" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d @bank-readonly.json

# Step 4: Create a new developer
curl -X POST "https://apigee.googleapis.com/v1/organizations/$DEVSHELL_PROJECT_ID/developers" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Joe",
    "lastName": "Developer",
    "userName": "joe",  
    "email": "joe@example.com"
  }'

echo

# Step 5: Provide final instructions
echo "${CYAN}${BOLD}Final Instructions${RESET}"

echo

echo -e "${BLUE}${BOLD}Go to this link to create an Apigee proxy: ${RESET}""https://console.cloud.google.com/apigee/proxy-create?project=$DEVSHELL_PROJECT_ID"
echo
echo -e "${YELLOW}${BOLD}Backend URL: ${RESET}""$(gcloud run services describe simplebank-rest --platform managed --region $REGION --format='value(status.url)')"
echo
echo -e "${CYAN}${BOLD}Copy this service account: ${RESET}""apigee-internal-access@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com"
echo




cd

remove_files() {
    # Loop through all files in the current directory
    for file in *; do
        # Check if the file name starts with "gsp", "arc", or "shell"
        if [[ "$file" == gsp* || "$file" == arc* || "$file" == shell* ]]; then
            # Check if it's a regular file (not a directory)
            if [[ -f "$file" ]]; then
                # Remove the file and echo the file name
                rm "$file"
                echo "File removed: $file"
            fi
        fi
    done
}

remove_files
