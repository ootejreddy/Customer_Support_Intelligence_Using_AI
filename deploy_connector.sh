#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
  # Export the variables so envsubst can substitute them
  export $(cat .env | grep -v '#' | awk '/=/ {print $1}')
else
  echo "Error: .env file not found. Please create one based on .env.example"
  exit 1
fi

# Use envsubst to replace placeholders in the JSON file and submit directly to Kafka Connect API
envsubst < snowflake-kafka-connector.json | curl -X POST -H "Content-Type: application/json" --data-binary @- http://localhost:8083/connectors

echo -e "\nConnector submission request completed."
