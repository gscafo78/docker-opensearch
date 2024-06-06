#!/bin/bash

# String to check
STRING="vm.max_map_count=512000"

# File to check and append to
FILE="/etc/sysctl.conf"

# Check if the string is present in the file
if ! grep -qF "$STRING" "$FILE"; then
  # String not found, append it to the file
  echo "$STRING" >> "$FILE"
  # Reload the sysctl configuration
  /usr/sbin/sysctl -p
  echo "Added '$STRING' to $FILE and reloaded sysctl settings."
else
  echo "'$STRING' is already present in $FILE."
fi

# Run the initialization script
/usr/bin/bash ./generate-certs.sh

# Check if the initialization script was successful
if [ $? -ne 0 ]; then
  echo "Initialization script failed. Exiting."
  exit 1
fi

/usr/bin/chown -R 1000:1000 certs

# Start Docker Compose
/usr/bin/docker compose up -d
echo "Waiting to to initialize the security plugin..."

sleep 40

while true; do
  # Run the command
  /usr/bin/docker compose exec os01 bash -c "chmod +x plugins/opensearch-security/tools/securityadmin.sh && bash plugins/opensearch-security/tools/securityadmin.sh -cd /usr/share/opensearch/config/opensearch-security/ -icl -nhnv -cacert config/certificates/ca/ca.pem -cert config/certificates/ca/admin.pem -key config/certificates/ca/admin.key -h localhost; exit \$?"

  # Check the exit status of the command
  if [ $? -eq 0 ]; then
    echo "Success: The securityadmin.sh script executed successfully."
    exit 0
  else
    echo "Error: The securityadmin.sh script failed to execute. Retrying in 20 seconds..."
  fi

  # Wait for 20 seconds before retrying
  sleep 20
done
