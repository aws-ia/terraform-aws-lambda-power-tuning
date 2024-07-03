#!/bin/bash

# clone aws-lambda-power-tuning repo if not present
if [ ! -d .aws-lambda-power-tuning ]; then
   git clone https://github.com/alexcasalboni/aws-lambda-power-tuning.git .aws-lambda-power-tuning
fi

# make sure we're working on the layer folder
cd .aws-lambda-power-tuning/layer-sdk

# create subfolders
## ./src is referenced by the LayerVersion resource (.gitignored)
## ./src/nodejs will contain the node_modules
mkdir -p ./src/nodejs

# install layer dependencies (the SDK)
npm i

# clean up previous build ...
rm -rf ./src/nodejs/node_modules

# ... and move everything into the layer sub-folder
mv ./node_modules ./src/nodejs