#!/bin/sh

set -e

if [ -z "$AWS_S3_BUCKET" ]; then
  echo "x AWS_S3_BUCKET is not set. Quitting."
  exit 1
else
  echo "- AWS_S3_BUCKET is set."
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "x AWS_ACCESS_KEY_ID is not set. Quitting."
  exit 1
else
  echo "- AWS_ACCESS_KEY_ID is set."
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "x AWS_SECRET_ACCESS_KEY is not set. Quitting."
  exit 1
else
  echo "- AWS_SECRET_ACCESS_KEY is set."
fi

# Default to us-east-1 if AWS_REGION not set.
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
  echo "x AWS_REGION not set, using default."
else
  echo "- AWS_REGION is set."
fi

# Override default AWS endpoint if user sets AWS_S3_ENDPOINT.
if [ -n "$AWS_S3_ENDPOINT" ]; then
  ENDPOINT_APPEND="--endpoint-url $AWS_S3_ENDPOINT"
  echo "- AWS_S3_ENDPOINT is set."
else
  echo "x AWS_S3_ENDPOINT is not set, using default."
fi

# Check if APPEND_FILE is set - if so, append timestamp to file
if [ -n "$APPEND_FILE" ]; then
  echo $'\n<!-- Build: '${GITHUB_REPOSITORY:-[none]} ${GITHUB_REF#refs/heads/:-[none]} ${GITHUB_SHA:-[none]}' '$(date -u)' -->' >> $APPEND_FILE
  echo "- APPEND_FILE is set. Appending timestamp to $APPEND_FILE."
else
  echo "x APPEND_FILE is not set, skipping appending timestamp."
fi

# Create a dedicated profile for this action to avoid conflicts
# with past/future actions.
aws configure --profile s3-sync-action <<-EOF > /dev/null 2>&1
${AWS_ACCESS_KEY_ID}
${AWS_SECRET_ACCESS_KEY}
${AWS_REGION}
text
EOF

# Sync using our dedicated profile and suppress verbose messages.
# All other flags are optional via the `args:` directive.
sh -c "aws s3 sync ${SOURCE_DIR:-.} s3://${AWS_S3_BUCKET}/${DEST_DIR} \
              --profile s3-sync-action \
              --no-progress \
              ${ENDPOINT_APPEND} $*"

# Check if Cloudfront Cache ID is set - if so, create an invalidation.
if [ "$AWS_CF_ID" ]; then
  echo "- AWS_CF_ID set. Creating invalidation..."
  sh -c "aws cloudfront create-invalidation --distribution-id ${AWS_CF_ID} --paths \"/*\""
else
  echo "x AWS_CF_ID is not set. Skipping cache bust step..."
fi

# Clear out credentials after we're done.
# We need to re-run `aws configure` with bogus input instead of
# deleting ~/.aws in case there are other credentials living there.
# https://forums.aws.amazon.com/thread.jspa?threadID=148833
aws configure --profile s3-sync-action <<-EOF > /dev/null 2>&1
null
null
null
text
EOF
