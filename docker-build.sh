#!/bin/bash
#IMAGE=${1:-caternberg/casc-custom-validator:amd64}

# 1. Create a builder that supports multi-arch (only need to do this once)
docker buildx create --use


IMAGE=${1:-caternberg/casc-schema-tools:arm64}
docker buildx build --platform linux/arm64 --build-arg TARGETARCH=arm64 -t ${IMAGE} --load .


