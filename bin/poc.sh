#!/bin/bash

# A quick and dirty proof of concept to capture bitwarden cli workflow
# A reduction to practice of the data From https://bitwarden.com/help/cli/

clear

####################################
## Step 0: Set to use tsys server
####################################
echo "Setting cli to use tsys bitwarden server..."

bw config server https://pwvault.turnsys.com

####################################
## Step 1: login to bitwarden
####################################

# From: https://bitwarden.com/help/cli/#using-an-api-key

### Set apikey environment varaible

echo "Sourcing clientid/apikey data..."
source D:/tsys/secrets/bitwarden/data/apikey-bitwarden-reachableceo

### Login to vault using apikey...

echo "Logging in..."
bw login --apikey $BW_CLIENTID $BW_CLIENTSECRET

### Step 1.1: unlock / save session id 

echo "Unlocking..."
export BW_SESSION="$(bw unlock --passwordenv TSYS_BW_PASSWORD_REACHABLECEO --raw)"


### Step 2: retrive a value into an environment variable

export PUSHOVER_APIKEY="$(bw get password APIKEY-pushover)"