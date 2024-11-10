#! /bin/bash

#set -x

#
# Variables
#

S3_BUCKET_PREFIX="tf-remote-backend-s3"
S3_BUCKET_POSTFIX=$(date +%Y%m%d%H%M%S%3N) # precise date so bucket name is globally unique
S3_BUCKET_NAME="$S3_BUCKET_PREFIX-$S3_BUCKET_POSTFIX"
S3_BUCKET_EXISTING=false
DDB_TABLE_NAME="tf-remote-backend-ddb"
ACTION=""

#
# Functions
#

# any existing backend bucket name needs to be known before starting
existing_bucket_name() {
    declare -a bucket_array
    bucket_list=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, '$S3_BUCKET_PREFIX')].Name" --output text)
    IFS=$'\t' read -r -a bucket_array <<< "$bucket_list"
    echo "bucket_array is ${bucket_array[@]}"
    if [[ ${#bucket_array[@]} == 0 ]]; then # test if array length is zero
        status1=1
    elif [[ ${#bucket_array[@]} == 1 ]]; then
        S3_BUCKET_NAME=${bucket_array[0]}
        echo "Existing S3 bucket found: $S3_BUCKET_NAME"
        S3_BUCKET_EXISTING=true
        status1=0
    else
        echo "There is more than one Terraform Backend S3 Bucket Present."
        echo "Please manually remove the extra bucket(s) before proceeding."
        exit 1
    fi
    }

# check if backend already exists; returns status code 1 if backend already exists
check_backend_present() {
    if [[ $S3_BUCKET_EXISTING == true ]]; then # check if bucket exists
        status1=0
    else
        status1=1
    fi
    aws dynamodb describe-table --table-name "$DDB_TABLE_NAME"
    status2=$?
    if [ "$status1" != 0 ] || [ "$status2" != 0 ]; then
        return 1 # error; infra not present
    else
        return 0 # no error; infra present
    fi
    }

# create s3 bucket
create_s3_bucket() {
    aws s3 mb "s3://$S3_BUCKET_NAME" --region $AWS_DEFAULT_REGION
    }

# delete s3 bucket
delete_s3_bucket() {
    aws s3 rm "s3://$S3_BUCKET_NAME" --recursive
    aws s3 rb "s3://$S3_BUCKET_NAME" --region $AWS_DEFAULT_REGION --force
    }

# create DynamoDB table
create_ddb_table() {
    aws dynamodb create-table \
      --table-name "$DDB_TABLE_NAME" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
      --region $AWS_DEFAULT_REGION
    }

# delete DynamoDB table
delete_ddb_table() {
    aws dynamodb delete-table \
      --table-name "$DDB_TABLE_NAME" \
      --region $AWS_DEFAULT_REGION
    }

#
# Main
#

main() {

    if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ] || [ -z "${AWS_DEFAULT_REGION}" ]; then
        echo "One or more AWS secrets/variables is not populated. Please enter them in Github settings."
        exit 1
    fi

    while getopts ":ead" option; do
        case $option in
            e)
                ACTION="environment";;
            a)
                ACTION="apply";;
            d)
                ACTION="destroy";;
            \?)
                echo "Error: Invalid option"
                exit 1;;
        esac
    done

    existing_bucket_name
    echo "Bucket Name is now $S3_BUCKET_NAME"

    if [[ $ACTION == "environment" ]]; then
        echo "S3_TF_STATE=$S3_BUCKET_NAME" >> "$GITHUB_ENV"
    fi

    if [[ $ACTION == "apply" ]]; then
        if ! check_backend_present; then
            echo 'TF backend not present; attempting to add it now'
            create_s3_bucket
            create_ddb_table
            echo "S3_TF_STATE=$S3_BUCKET_NAME" >> "$GITHUB_ENV"
        else
            echo 'Either a TF table or S3 bucket is already present; not adding any backend infra.'
            echo 'If you are intending to start clean, please re-run the GitHub Action for terraform-destroy.'
        fi
    fi

    if [[ $ACTION == "destroy" ]]; then
        if check_backend_present; then
            echo 'TF backend is present; attempting to delete it now'
            delete_s3_bucket
            delete_ddb_table
        else
            echo 'Delete was specified but there are no backend resources to remove.'
            echo 'This is acceptable if there have been multiple runs of the Destroy GitHub Action.'
        fi
    fi
}

main "$@"

