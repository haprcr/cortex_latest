echo "Begin Cortex Deployment"

#Project ID 
PROJECT_ID=$(gcloud config get-value project)
if [ "$PROJECT_ID" == "" ]; then 
    read -p "Enter Project Id: " PROJECT_ID
    #set the project 
    gcloud config set project $PROJECT_ID
else
    echo "The current project is " $PROJECT_ID
fi


echo -e "Select the activity you want to perform \n 1. Create VPC, Composer, Setup Firewall Rules and Permissions \n 2. Setup BigQuery \n 3. Mando Checker for Cortex 
 4. Cortex Selective Deployment \n 5. Copy Dags to Cloud Composer Bucket \n 6. Install Python Libraries for External Data (Optional. Required only if using external data) \n 7. Exit \n P.S.: Each step is a pre-requisite of the previous one BUT can be executed separately as well if the config for the previous step already exists" 
read -p "Enter a choice: " STEP_CHOICE
printf "\n"
#VPC
if [ "$STEP_CHOICE" == "1" ]; then 
read -p "Do you want to provide a VPC Name? ( If option N is selected, the default name as cortex_vpc will be set) Y/N ": VPC_NM_CHOICE
if [ "$VPC_NM_CHOICE" == "N" ]; then 
    VPC_NM="cortex-vpc"
else
    read -p "Enter the VPC Name: " VPC_NM    
fi
echo "The VPC Name set is " $VPC_NM
echo -e "\n Check if the VPC Exists"
gcloud compute networks describe $VPC_NM
if [ $? -eq 0 ]; then 
    echo -e "\n VPC " $VPC_NM " exists. "
    VPC_EXISTS="Y"
else
    echo -e "\n VPC " $VPC_NM " will be created"
fi

#get the project number
if [ $? -eq 0 ]; then
    export PROJECT_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
    if [ $? -eq 0 ]; then
        #set the region 

        read -p "Do you want to provide a region? If not then it will be set to us-central1 as default. ( Y/N ) ?" REGION_CHOICE
        if [ "$REGION_CHOICE" == 'N' ]; then 
            export REGION=us-central1
        else 
            read -p "Enter the region " REGION
        fi  
        echo "Region is set as " $REGION 
        echo -e "\n"
        read -p " Do you want to provide a user managed service account already created? (Y / N) ?" UMSA
        if [ "$UMSA" == "N" ]; then
            export UMSA=cortex-deployer-sa 
        else 
            read -p  "Enter service account name (not the entire id, just the name ) " UMSA
        fi 
        echo "Service account is " $UMSA

        #set up the service account id's
        export UMSA_FQN=$UMSA@${PROJECT_ID}.iam.gserviceaccount.com
        export CBSA_FQN=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
        export ADMIN_FQ_UPN=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

        export VPC_FQN=projects/${PROJECT_ID}/global/networks/${VPC_NM}

        read -p "Do you want to keep the subnet name default as us-central1 ? ( Y/N )?" SUBNET_CHOICE
        if [ "$SUBNET_CHOICE" == "Y" ]; then 
            export SUBNET_NM=us-central1
        else 
            read -p "Provide the subnet name " SUBNET_NM
        fi
        echo "The Subnet will be created as " $SUBNET_NM
        echo -e "\n"
        read -p "Do you want to keep the composer name default as ${PROJECT_ID}-cortex ? ( Y/N )?" COMPOSER_CHOICE
        if [ "$COMPOSER_CHOICE" == "Y" ]; then 
            export COMPOSER_ENV_NM=us-central1
        else 
            read -p "Provide the composer name " COMPOSER_ENV_NM
        fi
        #export COMPOSER_ENV_NM=$PROJECT_ID-cortex
        echo "The composer name is" $COMPOSER_ENV_NM

        echo -e "\n Enabling required apis ( composer, storage, cloid resource manager, orgpolicy, compute, monitoring, cloudtrace, clouddebugger ) "
        gcloud services enable \
    composer.googleapis.com \
    storage-component.googleapis.com \
    cloudresourcemanager.googleapis.com \
    orgpolicy.googleapis.com \
    compute.googleapis.com \
    monitoring.googleapis.com \
    cloudtrace.googleapis.com \
    clouddebugger.googleapis.com
    
    if [ "$VPC_EXISTS" != "Y" ]; then
    echo -e "\n Creating the VPC Networks "
    gcloud compute networks create -q ${VPC_NM} \
    --project=${PROJECT_ID} \
    --subnet-mode=custom \
    --mtu=1460 \
    --bgp-routing-mode=regional

    echo -e "\n Creating Subnet "
    gcloud compute networks subnets create -q ${SUBNET_NM} \
    --project=${PROJECT_ID} \
    --network=${VPC_NM} \
    --range=10.0.0.0/24 \
    --region=${REGION}


    echo -e "\n Creating Firewall Rules "
    gcloud compute firewall-rules create -q allow-all-intra-vpc \
    --project=${PROJECT_ID} \
    --network=${VPC_FQN} \
    --direction=INGRESS \
    --priority=65534 \
    --source-ranges=10.0.0.0/20 \
    --action=ALLOW \
    --rules=all

    gcloud compute firewall-rules create -q allow-all-ssh \
    --project=$PROJECT_ID \
    --network=$VPC_FQN \
    --direction=INGRESS \
    --priority=65534 \
    --source-ranges=0.0.0.0/0 \
    --action=ALLOW \
    --rules=tcp:22
    fi

    echo -e "\n Creating User Managed Service Account"
    gcloud iam service-accounts create -q ${UMSA} \
    --description="User Managed Service Account for Cortex Deployment" \
    --display-name=$UMSA

    echo -e "\n Grant IAM Permissions specific for cloud composer to User Managed Service Account ${UMSA_FQN} " 
    for role in 'roles/composer.admin' \
    'roles/iam.serviceAccountTokenCreator' \
    'roles/composer.worker' \
    'roles/storage.objectViewer' \
    'roles/iam.serviceAccountUser' ; do \
    gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="serviceAccount:${UMSA_FQN}" \
    --role="$role"
    done

    echo -e "\n Grant Permissions for the Admin ${ADMIN_FQ_UPN} to access/use the User Managed Service Account ${UMSA_FQN}"  
    for role in 'roles/iam.serviceAccountUser' \
'roles/iam.serviceAccountTokenCreator' \
'roles/iam.serviceAccountUser' ; do \
    gcloud iam service-accounts add-iam-policy-binding -q ${UMSA_FQN} \
        --member="user:${ADMIN_FQ_UPN}" \
        --role="$role"
done

    echo -e "\n Grant Permissions for the admin ${ADMIN_FQ_UPN} to change the configuration of cloud composer "
    for role in 'roles/composer.admin' \
'roles/composer.worker' \
'roles/storage.objectViewer' \
'roles/composer.environmentAndStorageObjectViewer' ; do \
    gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
        --member=user:${ADMIN_FQ_UPN} \
        --role="$role"        
done

gcloud iam service-accounts add-iam-policy-binding \
    ${UMSA_FQN} \
    --member serviceAccount:service-${PROJECT_NUMBER}@cloudcomposer-accounts.iam.gserviceaccount.com \
    --role roles/composer.ServiceAgentV2Ext

    echo -e "The variables to be passed to create the composer will be as follows: \n " 
    echo "Composer Environment Name: " $COMPOSER_ENV_NM
    echo "Region " $REGION
    echo "Network " $VPC_NM
    echo "Subnetwork " $SUBNET_NM
    echo "Service Account " $UMSA_FQN
    echo -e "\n Creating the cloud composer environment"
    gcloud composer environments create ${COMPOSER_ENV_NM} \
    --location ${REGION} \
    --labels env=dev,purpose=cortex-data-foundation \
    --network ${VPC_NM} \
    --subnetwork ${SUBNET_NM} \
    --service-account ${UMSA_FQN} \
    --async


    else
        echo "setting the project number failed"
    fi 
else
echo "project id set failed"
fi
fi

### BIG QUERY SETUP ################
if [ "$STEP_CHOICE" == "2" ]; then 
echo "BQ Setup"

#Project ID 
PROJECT_ID=$(gcloud config get-value project)
if [ "$PROJECT_ID" == "" ]; then 
    read -p "Enter Project Id: " PROJECT_ID
    #set the project 
    gcloud config set project $PROJECT_ID
else
    echo "The current project is " $PROJECT_ID
fi

#Set Project Number
export PROJECT_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
echo -e "\n The project number is  ${PROJECT_NUMBER} "

#Set the region
read -p "Enter the region that you have set for the composer environment: " REGION
echo -e "\n The Region is ${REGION}"

#Set the BigQuery Region as US
read -p "Enter the Multi Region for BQ. Default Value will be set as US. Please leave it as blank if you want to set it as the default value" BQ_REGION
if [ "$BQ_REGION" == "" ]; then 
    BQ_REGION=US
    echo -e "\n The BQ Region is ${BQ_REGION}"
else
    echo -e "\n The BQ Region is ${BQ_REGION}"
fi

#set the user managed service account
read -p "Enter the User Managed Service Account name. If you have used the default value, leave it as blank" UMSA
if [ "$UMSA" == "" ]; then 
    UMSA=cortex-deployer-sa
    echo -e "\n The UMSA is ${UMSA}"
else
    echo -e "\n The UMSA is ${UMSA}"
fi


#set derived variables
export UMSA_FQN=$UMSA@${PROJECT_ID}.iam.gserviceaccount.com
export CBSA_FQN=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
export ADMIN_FQ_UPN=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

#enable BQ api 
echo -e "\n Enable BigQuery API Service"
gcloud services enable bigquery.googleapis.com

#grant permission
echo -e "\n Grant IAM Permission to User Managed Service Account for BigQuery Tasks "
for role in 'roles/bigquery.admin' \
'roles/bigquery.dataEditor' \
'roles/cloudbuild.builds.editor' ; do \
    gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
        --member=serviceAccount:${UMSA_FQN} \
        --role="$role"
done

echo -e "\n Grant IAM Permissions to Cloud Build Service Account for BigQuery Tasks"
for role in 'roles/bigquery.dataEditor' \
'roles/bigquery.jobUser' \
'roles/storage.objectAdmin' ; do \
    gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
        --member=serviceAccount:${CBSA_FQN} \
        --role="$role"
done

#create datasets
read -p "Enter the RAW Dataset Name: " RAW_LANDING
bq --location=${BQ_REGION} mk -d ${RAW_LANDING}

read -p "Enter the CDC Dataset Name: " CDC_PROCESSED
bq --location=${BQ_REGION} mk -d ${CDC_PROCESSED}

#create the cloud storage buckets 
read -p "Enter the Cloud Storage Bucket Name that you want to be created for dags. Leave blank and hit enter for the default name as PROJECTNAME-dags" DAGS_BUCKET
if [ "$DAGS_BUCKET" == "" ]; then
    export DAGS_BUCKET=${PROJECT_ID}-dags
fi
echo -e "\n DAGS Bucket name is " $DAGS_BUCKET 
gsutil mb -l ${REGION} gs://${DAGS_BUCKET}

read -p "Enter the Cloud Storage Bucket Name that you want to be created for logs. Leave blank and hit enter for the default name as PROJECTNAME-logs" LOGS_BUCKET
if [ "$LOGS_BUCKET" == "" ]; then
    export LOGS_BUCKET=${PROJECT_ID}-logs
fi
echo -e "\n LOGS Bucket name is " $LOGS_BUCKET 
gsutil mb -l ${REGION} gs://${LOGS_BUCKET}
fi

### CORTEX DEPLOYMENT SETUP ################
if [ "$STEP_CHOICE" == "3" ]; then 
echo "Deploy Cortex"

echo -e "\n Perform Mando Checker - Checks performed to assess if the cortex build will work fine or not and whether the existing setup has the necessary permissions "
rm -rf mando-Checker

echo -e "\n Clone the Mando Checker Repo"
git clone  https://github.com/fawix/mando-checker
cd mando-checker

#Project ID 
PROJECT_ID=$(gcloud config get-value project)
if [ "$PROJECT_ID" == "" ]; then 
    read -p "Enter Project Id: " PROJECT_ID
    #set the project 
    gcloud config set project $PROJECT_ID
else
    echo "The current project is " $PROJECT_ID
fi

read -p "Enter the Cloud Storage Bucket Name that you want to be created for dags. Leave blank and hit enter for the default name as PROJECTNAME-dags" DAGS_BUCKET
if [ "$DAGS_BUCKET" == "" ]; then
    export DAGS_BUCKET=${PROJECT_ID}-dags
fi

read -p "Enter the Cloud Storage Bucket Name that you want to be created for logs. Leave blank and hit enter for the default name as PROJECTNAME-logs" LOGS_BUCKET
if [ "$LOGS_BUCKET" == "" ]; then
    export LOGS_BUCKET=${PROJECT_ID}-logs
fi

echo -e "\n Run the mando checker "
gcloud builds submit \
   --project ${PROJECT_ID} \
   --substitutions _DEPLOY_PROJECT_ID=${PROJECT_ID},_DEPLOY_BUCKET_NAME=${DAGS_BUCKET},_LOG_BUCKET_NAME=${LOGS_BUCKET} .

echo -e "\n Delete the mando checker folder"
cd .. && rm -rf mando-checker


fi

if [ "$STEP_CHOICE" == "4" ]; then

echo -e "This Step requires the config.json file to be updated with the information required."
printf "\n"

#Project ID 
PROJECT_ID=$(gcloud config get-value project)
if [ "$PROJECT_ID" == "" ]; then 
    read -p "Enter Project Id: " PROJECT_ID
    #set the project 
    gcloud config set project $PROJECT_ID
else
    echo "The current project is " $PROJECT_ID
fi


read -p "Enter the Cloud Storage Bucket Name that you want to be created for logs. Leave blank and hit enter for the default name as PROJECTNAME-logs:  " LOGS_BUCKET
if [ "$LOGS_BUCKET" == "" ]; then
    export LOGS_BUCKET=${PROJECT_ID}-logs
fi
echo -e "\n LOGS Bucket name is " $LOGS_BUCKET 

printf "\n"

valid_selection=false
while ! "$valid_selection"; do
    echo -e "Please select one of the option below for the Cortex Deployment"
    printf "\n"
    echo -e "1.  Perform Cortex Deployment"
    echo -e "2.  Perform Selective Cortex Deployment on Functional Areas"
    echo -e "3.  Perform Selective Cortex Deployment on Data Models"

    read -p "Enter one among the options [1,2,3]: " deployment_choice
    
    if [ "$deployment_choice" -ge 1 ] && [ "$deployment_choice" -le 3 ]; then
        valid_selection=true
    else
        echo "Invalid selection. Please enter valid option."
    fi
done

if [ "$deployment_choice" == "1" ]; then
        printf "Cortex Deployment Started..."
        printf "\n"

        EXTERNAL_DAGS=("currency_conversion" "prod_hierarchy_texts" "inventory_snapshots")
        REPORTING_DAGS=("currency_conversion" "prod_hierarchy_texts" "inventory_snapshots")
        
        ext_dag_str=$(printf "\"%s\" " "${EXTERNAL_DAGS[@]}")
        reporting_dag_str=$(printf "\"%s\" " "${REPORTING_DAGS[@]}")

        # Remove the extra space at the end
        ext_dag_str="${ext_dag_str%" "}"
        reporting_dag_str="${reporting_dag_str%" "}"

        # Replace the contents of the array.
        pushd src/SAP/SAP_REPORTING/
        sed -i -e "s/EXTERNAL_DAGS=(\".*\")/EXTERNAL_DAGS=($ext_dag_str)/" generate_external_dags.sh
        sed -i -e "s/REPORTING_DAGS=(\".*\")/REPORTING_DAGS=($reporting_dag_str)/" generate_external_dags.sh
        popd

        choice_list=("1" "1" "1")
        pushd src/SAP/SAP_CDC/
        python3 selective_deployment_cdc.py  "${choice_list[@]}" "functional_area_deployment" && _SUCCESS='true'
        popd

        if [[ "${_SUCCESS}" != "true" ]]; then
            echo -e "\n🛑 CDC Settings file is not updated with the required base tables. 🛑"
            exit 1
        else
            echo -e "\n✅ CDC Settings file is updated with the required base tables. 🦄"
            pushd src/SAP/SAP_REPORTING/
            python3 selective_deployment_reporting.py  "${choice_list[@]}" "functional_area_deployment" && _SUCCESS="true"
            popd
            if [[ "${_SUCCESS}" != "true" ]]; then
                echo -e "\n🛑 REPORTING Settings file is not updated with the required base tables. 🛑"
                exit 1
            else
                echo -e "\n✅ REPORTING Settings file is updated with the required base tables. 🦄"
            fi
        fi

        gcloud builds submit  --substitutions=_GCS_BUCKET=cortex_logs_hp_1
fi

if [ "$deployment_choice" == "2" ]; then
    # cortex deployment for SAP
    EXTERNAL_DAGS=("currency_conversion" "prod_hierarchy_texts" "inventory_snapshots")
    REPORTING_DAGS=("currency_conversion" "prod_hierarchy_texts" "inventory_snapshots")
        
    ext_dag_str=$(printf "\"%s\" " "${EXTERNAL_DAGS[@]}")
    reporting_dag_str=$(printf "\"%s\" " "${REPORTING_DAGS[@]}")

    # Remove the extra space at the end
    ext_dag_str="${ext_dag_str%" "}"
    reporting_dag_str="${reporting_dag_str%" "}"

    # Replace the contents of the array.
    pushd src/SAP/SAP_REPORTING/
    sed -i -e "s/EXTERNAL_DAGS=(\".*\")/EXTERNAL_DAGS=($ext_dag_str)/" generate_external_dags.sh
    sed -i -e "s/REPORTING_DAGS=(\".*\")/REPORTING_DAGS=($reporting_dag_str)/" generate_external_dags.sh
    popd

    valid_responses=("Y" "N" "y" "n")

    while true; do
        echo -e "Do you want to deploy the functional areas selectively"
        echo -e "Please type Y if you want to perform Selective Deployment"
        echo -e "Please type N if you do not want to perform Selective Deployment"
        read -p "Y/N:" response

        if [[ ! " ${valid_responses[*]} " =~ " ${response} " ]]; then
            echo "Invalid response. Please enter 'Y' or 'N'."
        else
            break
        fi
    done

    choice_list=()

    if [ "${response}" == "Y" ] || [ "${response}" == "y" ]; then
        echo "Begin Functional Area Deployment........"
        
        
        valid_selection=false
        while ! "$valid_selection"; do
        echo -e "Do you want to deploy Inventory Dashboard"
        echo -e "✅ Enter 1 for Yes"
        echo -e "🛑 Enter 0 for No"
        read -p "Enter a choice: " choice_inventory
        
        if [ "$choice_inventory" -ne 0 ] && [ "$choice_inventory" -ne 1 ]; then
            echo "Invalid input. Please enter either 0 or 1."
        else
            valid_selection=true
        fi
        done
        choice_list[0]="$choice_inventory"


        valid_selection=false
        while ! "$valid_selection"; do
        echo -e "Do you want to deploy Finance Dashboard"
        echo -e "✅ Enter 1 for Yes"
        echo -e "🛑 Enter 0 for No"
        read -p "Enter a choice: " choice_finance
        
        if [ "$choice_finance" -ne 0 ] && [ "$choice_finance" -ne 1 ]; then
            echo "Invalid input. Please enter either 0 or 1."
        else
            valid_selection=true
        fi
        done
        choice_list[1]="$choice_finance"


        valid_selection=false
        while ! "$valid_selection"; do
        echo -e "Do you want to deploy Order to Cash Dashboard"
        echo -e "✅ Enter 1 for Yes"
        echo -e "🛑 Enter 0 for No"
        read -p "Enter a choice: " choice_o2c
        
        if [ "$choice_o2c" -ne 0 ] && [ "$choice_o2c" -ne 1 ]; then
            echo "Invalid input. Please enter either 0 or 1."
        else
            valid_selection=true
        fi
        done
        choice_list[2]="$choice_o2c"


        pushd src/SAP/SAP_CDC/
        python3 selective_deployment_cdc.py  "${choice_list[@]}" "functional_area_deployment" && _SUCCESS='true'
        popd

        if [[ "${_SUCCESS}" != "true" ]]; then
            echo -e "\n🛑 CDC Settings file is not updated with the required base tables. 🛑"
            exit 1
        else
            echo -e "\n✅ CDC Settings file is updated with the required base tables. 🦄"
            pushd src/SAP/SAP_REPORTING/
            python3 selective_deployment_reporting.py  "${choice_list[@]}" "functional_area_deployment" && _SUCCESS="true"
            popd
            if [[ "${_SUCCESS}" != "true" ]]; then
                echo -e "\n🛑 REPORTING Settings file is not updated with the required base tables. 🛑"
                exit 1
            else
                echo -e "\n✅ REPORTING Settings file is updated with the required base tables. 🦄"
            fi
        fi

        gcloud builds submit  --substitutions=_GCS_BUCKET=cortex_logs_hp_1

        if ["$choice_inventory" == 1]; then
            echo -e "Inventory Functional Module is deployed Successfully!!!"
        fi

        if ["$choice_finance" == 1]; then
            echo -e "Finance Functional Module is deployed Successfully!!!"
        fi

        if ["$choice_o2c" == 1]; then
            echo -e "Order To Cash Functional Module is deployed Successfully!!"
        fi
    else
        echo "You chose not to continue with Selective Deployment."
    fi
fi

if [ "$deployment_choice" == "3" ]; then
    echo "Starting Selective Deployment on Data Models......"
    # Defined list of options
    data_models=("AccountingDocumentsReceivable"
            "CurrencyConversion"
            "currency_decimal"
            "AccountsPayable"
            "AccountsPayableTurnover"
            "DaysPayableOutstanding"
            "CashDiscountUtilization"
            "VendorPerformance"
            "MaterialLedger"
            "Languages_T002"
            "InventoryByPlant"
            "InventoryKeyMetrics"
            "SalesOrders_V2"
            "Deliveries"
            "Billing"
            "MaterialsMD"
            "CustomersMD"
            "CountriesMD"
            "SalesOrganizationsMD"
            "DistributionChannelsMD"
            "SalesOrderPricing"
            "OneTouchOrder"
            "SalesOrderScheduleLine"
            "DivisionsMD"
            "SalesOrderHeaderStatus"
            "SalesOrderPartnerFunction")


    # Display available options
    for idx in "${!data_models[@]}"; do 
    i=$(expr $idx + 1)
    printf "%s\t%s\n" "$i" "${data_models[$idx]}"
    done

    # Function to validate user input and convert ranges to comma-separated values
    validate_input() {
        local user_input="$1"

        # Remove spaces and convert range notation (e.g., 1-4) to comma-separated values
        user_input=$(echo "$user_input" | tr -d ' ')
        local cleaned_input=""

        IFS=',' read -ra user_selected_options <<< "$user_input"
        for ele in "${user_selected_options[@]}"; do
            if [[ "$ele" =~ ^[1-9][0-9]*-[1-9][0-9]*$ ]]; then
                IFS='-' read -ra option_range <<< "$ele"
                if [ "${option_range[0]}" -ge 1 ] && [ "${option_range[0]}" -le $(( ${#data_models[@]} - 1 )) ] && [ "${option_range[1]}" -gt "${option_range[0]}" ] && [ "${option_range[1]}" -le ${#data_models[@]} ]; then
                    cleaned_input+=$(seq -s, "${option_range[0]}" "${option_range[1]}")","
                fi
            else
                if [ "$ele" -ge 1 ] && [ "$ele" -le ${#data_models[@]} ]; then
                    cleaned_input+="$ele,"
                fi
            fi
        done

        # Remove trailing comma if present
        cleaned_input="${cleaned_input%,}"
        echo "$cleaned_input"
    }


    valid_selection=false
    while ! "$valid_selection"; do
        echo "Select the data models by entering their numbers (1-26) separated by commas (e.g., 3,4,7 or 1-4):"
        read -p "Options: " user_selection
        cleaned_input=$(validate_input "$user_selection")

        if [[ -n "$cleaned_input" ]]; then
            IFS=',' read -ra selected_options <<< "$cleaned_input"
            valid_selection=true
        else
            echo "Invalid selection. Please enter valid numbers or ranges."
        fi
    done


    data_models_list=()
    echo "You selected the following Data Models:"

    for option_num in "${selected_options[@]}"; do
        printf "%s)\t%s\n" "$option_num" "${data_models[option_num - 1]}"
        data_models_list+=("${data_models[option_num - 1]}")
    done



    external_dag_data="data_models.json"

    for data_model in "${data_models_list[@]}"; do 
        ext_dag_list+=($(jq -r ".${data_model}.external_dag[]" "$external_dag_data"))
    done

    # Sort the array and remove duplicates
    unique_ext_dag=($(printf "%s\n" "${ext_dag_list[@]}" | sort -u))

    # Combine the elements into a string with double quotes and spaces
    unique_ext_dag_str=$(printf "\"%s\" " "${unique_ext_dag[@]}")

    # Remove the extra space at the end
    unique_ext_dag_str="${unique_ext_dag_str%" "}"

    # Replace the contents of the array.
    pushd src/SAP/SAP_REPORTING/
    sed -i -e "s/EXTERNAL_DAGS=(\".*\")/EXTERNAL_DAGS=($unique_ext_dag_str)/" generate_external_dags.sh
    sed -i -e "s/REPORTING_DAGS=(\".*\")/REPORTING_DAGS=($unique_ext_dag_str)/" generate_external_dags.sh
    popd

    pushd src/SAP/SAP_CDC/
    python3 selective_deployment_cdc.py  "${data_models_list[@]}" "data_model_deployment" && _SUCCESS='true'
    popd


    if [[ "${_SUCCESS}" != "true" ]]; then
            echo -e "\n🛑 CDC Settings file is not updated with the required base tables. 🛑"
            exit 1
    else
            echo -e "\n✅ CDC Settings file is updated with the required base tables. 🦄"
            pushd src/SAP/SAP_REPORTING/
            python3 selective_deployment_reporting.py  "${data_models_list[@]}" "data_model_deployment" && _SUCCESS="true"
            popd
            if [[ "${_SUCCESS}" != "true" ]]; then
                echo -e "\n🛑 REPORTING Settings file is not updated with the required base tables. 🛑"
                exit 1
            else
                echo -e "\n✅ REPORTING Settings file is updated with the required base tables. 🦄"
                gcloud builds submit  --substitutions=_GCS_BUCKET=cortex_logs_hp_1
            fi
    fi
fi
fi

### COPY DAGS TO COMPOSER'S BUCKET
if [ "$STEP_CHOICE" == "5" ]; then 

echo "Setup the environment variables required to execute the command."
export PROJECT_ID=$(gcloud config get-value project)
echo -e "\n The project id is ${PROJECT_ID}"

read -p "Enter the Region. Default Value will be us-central1: " REGION
if [ "$REGION" == "" ]; then 
REGION=us-central1
fi

read -p "Enter the name of the Composer Environment. Default Value will be projectid-cortex: " COMPOSER_ENV_NM
if [ "$COMPOSER_ENV_NM" == "" ]; then 
COMPOSER_ENV_NM=$PROJECT_ID-cortex
fi

echo -e "\n The Project ID, Region and Composer Environment is as follows: "
echo -e "\n ${PROJECT_ID}, ${REGION}, ${COMPOSER_ENV_NM}"

echo -e "\n Get the bucket name generated from the composer environment"
export COMPOSER_GEN_BUCKET_FQN=$(gcloud composer environments describe ${COMPOSER_ENV_NM} --location=${REGION} --format='value(config.dagGcsPrefix)')
export COMPOSER_GEN_BUCKET_NAME=$(echo ${COMPOSER_GEN_BUCKET_FQN} | cut -d'/' -f 3)
echo -e "\n The composer bucket name is ${COMPOSER_GEN_BUCKET_NAME}"

#create the cloud storage buckets 
read -p "Enter the Cloud Storage Bucket Name that you have created for dags. Leave blank and hit enter for the default name as PROJECTNAME-dags" DAGS_BUCKET
if [ "$DAGS_BUCKET" == "" ]; then
    export DAGS_BUCKET=${PROJECT_ID}-dags
fi
echo -e "\n DAGS Bucket name is " $DAGS_BUCKET 


echo -e "\n Copy Dags from the GCS Bucket for DAGS to the Cloud Composer's DAG's Bucket"
export SRC_DAGS_BUCKET=$(echo gs://${DAGS_BUCKET}/dags)
export TGT_DAGS_BUCKET=$(echo gs://${COMPOSER_GEN_BUCKET_NAME}/dags)

echo -e "\n The DAGS Bucket name is ${DAGS_BUCKET} \n The Cloud Composer's Bucket name is ${COMPOSER_GEN_BUCKET_NAME} \n"
gsutil -m cp -r  ${SRC_DAGS_BUCKET} ${TGT_DAGS_BUCKET}


export SRC_DATA_BUCKET=$(echo gs://${DAGS_BUCKET}/data)
export TGT_DATA_BUCKET=$(echo gs://${COMPOSER_GEN_BUCKET_NAME}/data)
gsutil -m cp -r  ${SRC_DATA_BUCKET} ${TGT_DATA_BUCKET}



fi

if [ "$STEP_CHOICE" == "6" ]; then 


    read -p "Enter the composer name for which you want to install the additional python libraries" COMPOSER_ENV_NM
    read -p "Enter the region in which the composer is created" REGION

    echo -e "\n Check if the composer's state. The libraries can be installed only if the composer is running." 
    
    export COMPOSER_STATE=$(gcloud composer environments list --locations=${REGION} --filter="${COMPOSER_ENV_NM}" --format="value(STATE)")

    if [ "$COMPOSER_STATE" == "RUNNING" ];then 
    echo -e "The composer state is RUNNING. Installing python libraries now \n"
    gcloud composer environments update ${COMPOSER_ENV_NM} \
    --location ${REGION} \
    --update-pypi-package holidays \
    --update-pypi-package pytrends \
    --update-pypi-package simple-salesforce \
    --update-pypi-package apache-airflow-providers-salesforce \
    --async


    else
    echo "The composer state is ${COMPOSER_STATE}. Please wait for the state to come till running"
    fi
fi

if [ "$STEP_CHOICE" == "7" ]; then 
exit
fi

#export PROJECT_ID=$(gcloud config get-value project)
#export PROJECT_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
#if [$PROJECT_NUMBER -ne "" ]
#then 
##echo "project number is " $PROJECT_NUMBER
#else
#echo "project number not set" $PROJECT_NUMBER
#fi
