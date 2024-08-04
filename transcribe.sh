#!/bin/bash

set -x
set -eo pipefail

# NB: expect API_KEY to be passed as env var
# NB: expect HF_TOKEN to be passed as env var for diarization

API_URL=https://cloud.lambdalabs.com/api/v1

# TODO encode input into small but reasonably high quality for transcription
# TODO encode input into lossless archival format

# Add local SSH key to account if not present
local_keys=(~/.ssh/id_*.pub)

# TODO: error handling if no ssh keys...

avail_keys=$(
curl --fail --silent -u "${API_KEY}" "${API_URL}/ssh-keys" \
  | jq '.data'
)

ssh_key_name=
for k in "${local_keys[@]}" ; do
  n=$(echo "${avail_keys}" | jq -r 'map(select(.public_key == "'"$(cat "$k")"'")) | .[0].name')
  if [[ -n $n ]] ; then
    echo "${k} already present in account as ${n}"
    ssh_key_name=$n
    break;
  fi
done

# if none of the local keys are on the account, add one arbitrary one
if [[ -z $ssh_key_name ]] ; then
  k=${local_keys[0]}
  ssh_key_name=$(basename ${k})-$(hostname)

  echo "adding ${k} to account as $ssh_key_name"
  curl --fail --silent -u "${API_KEY}" "${API_URL}/ssh-keys" -X POST \
    -d '{"name":" '"${ssh_key_name}"'", "public_key": "'"$(cat ${k})"'"}'
fi

# find cheapest singe-GPU instance type with availability
best_gpu=$(
curl --fail --silent -u "${API_KEY}" "${API_URL}/instance-types" \
  | jq '.data | map(select(.regions_with_capacity_available | length > 0) | select(.instance_type.specs.gpus == 1)) | sort_by(.instance_type.price_cents_per_hour) | .[0]'
)

# TODO: handle error case where no availability for single-gpu instance
# TODO: cap out hourly price

instance_type=$(echo "${best_gpu}" | jq -r '.instance_type.name')
region_name=$(echo "${best_gpu}" | jq -r '.regions_with_capacity_available[0].name')

echo "spinning up $instance_type in $region_name"

instance_id=$(
{
tee /dev/stderr <<EOF
{
  "region_name": "$region_name",
  "instance_type_name": "$instance_type",
  "ssh_key_names": ["${ssh_key_name}"]
}
EOF
} | curl --fail --silent -u "${API_KEY}" -H "Content-Type: application/json" \
  ${API_URL}/instance-operations/launch \
  -d @- \
| jq -r '.data.instance_ids[0]'
)

# TODO: add trap handler to print full termination command for easy cleanup on failure

echo "launched instance $instance_id"
echo

set +x

# wait for instance to be done booting
while true ; do
  instance_data=$(
    curl --fail --silent -u "${API_KEY}" "${API_URL}/instances/${instance_id}" \
    | tee /dev/stderr \
    | jq .data
  )
  instance_status=$(echo "${instance_data}" | jq -r .status)
  if [[ "$instance_status" == "active" ]] ; then
    break;
  fi

  sleep 1
  echo -n .
done

set -x

instance_ip=$(echo "${instance_data}" | jq -r .ip )

echo "ready at $instance_ip"

# copy inputs over, in background
# TODO: manage stderr/stdout
scp ${@} ubuntu@${instance_ip}:~/ &

# setup instance to run fast and high quality Whisper transcription
# see https://github.com/Vaibhavs10/insanely-fast-whisper
ssh -o "StrictHostKeyChecking no" ubuntu@${instance_ip} <<EOF
sudo apt -o Apt::Get::Assume-Yes=true install pipx jq
pipx install insanely-fast-whisper
pipx runpip insanely-fast-whisper install flash-attn --no-build-isolation
EOF

# wait for background upload to be done
echo "waiting for input(s) to be uploaded"
wait

# run transcription on cloud GPU instance
for f in "${@}" ; do
  echo "transcribe ${f}"

  bf=$(basename "$f")
  of=$(dirname "$f")/transcript-$bf.json

  ssh -o "StrictHostKeyChecking no" ubuntu@${instance_ip} <<EOF
    insanely-fast-whisper \
    --file-name "$bf" \
    --flash True \
    ${HF_TOKEN:+--hf-token ${HF_TOKEN}} \
    --transcript-path "transcript-$bf.json"
EOF

  # copy transcription output back to local machine
  scp ubuntu@${instance_ip}:~/transcript-$bf.json" "$of"
  echo "saved output as $of"
fi

echo "terminating $instance_id"

curl --fail --silent -u "${API_KEY}" -H "Content-Type: application/json" \
  ${API_URL}/instance-operations/launch \
  -d @- <<EOF
{
  "instance_ids": ["$instance_id"]
}
EOF

echo "terminated"

