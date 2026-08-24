#! /bin/bash

IMAGE=${1:-caternberg/casc-schema-tools:arm64}

echo "===================================================="
echo  "Docker build"
#./docker-build.sh $IMAGE

echo "===================================================="
echo  "Generate custom Schema"
docker run --rm -v $(pwd):/work $IMAGE bash -c "yq . jenkins.yaml -o json | python3 -m genson - | jq . > custom-jenkins-schema.json"
echo "===================================================="
echo "Set const 'cloudBeesRoleBasedAccessControl'for authorizationStrategy"
cp custom-jenkins-schema.json custom-jenkins-schema.json.bak
jq '.properties.jenkins.properties.authorizationStrategy |= (. + {"const": "cloudBeesRoleBasedAccessControl"})' \
  custom-jenkins-schema.json > tmp.$$.json && mv tmp.$$.json custom-jenkins-schema.json
diff custom-jenkins-schema.json custom-jenkins-schema.json.bak

echo "===================================================="
echo  "validate against custom schema"
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile custom-jenkins-schema.json ./jenkins.yaml

echo "===================================================="
echo  "validate against custom schema - unexpected value for authorizationStrategy"

# Workaround: fix yaml indent
TMP_DIR=$(mktemp -d)
OUTPUT_FILE=$TMP_DIR/"tmp-jenkins-patched.yaml"
# Copy the original to modify
cp -f jenkins.yaml $OUTPUT_FILE
yq e --indent=2 --no-colors '.' "$OUTPUT_FILE" > tmp.yaml && mv tmp.yaml "jenkins.yaml"
# END Workaround: fix yaml indent

yq '.jenkins.authorizationStrategy = "somethingelse"' jenkins.yaml > jenkins-wrong-auth.yaml
diff jenkins.yaml jenkins-wrong-auth.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile custom-jenkins-schema.json ./jenkins-wrong-auth.yaml

#echo "validate against default schema"
#docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile default-jenkins-schema.json ./jenkins.yaml

echo "===================================================="
echo "Test: pre-commit hook blocks a commit of the invalid bundle"

git config core.hooksPath .githooks

# Stage the invalid bundle (jenkins-wrong-auth.yaml) as jenkins.yaml, the file
# the pre-commit hook actually validates, then try to commit it.
cp jenkins-wrong-auth.yaml jenkins.yaml
git add jenkins.yaml

COMMIT_OUTPUT=$(git commit -m "test: invalid authorizationStrategy (should be blocked)" 2>&1)
COMMIT_STATUS=$?
echo "$COMMIT_OUTPUT"

if [ $COMMIT_STATUS -eq 0 ]; then
    echo "FAIL: pre-commit hook did NOT block the invalid jenkins.yaml"
    git reset --soft HEAD~1
elif echo "$COMMIT_OUTPUT" | grep -q "commit aborted"; then
    echo "PASS: pre-commit hook correctly blocked the invalid jenkins.yaml"
else
    echo "FAIL: commit was blocked, but not by the pre-commit hook (see output above)"
fi

# Clean up: unstage and restore the original, valid jenkins.yaml
git restore --staged jenkins.yaml 2>/dev/null || git reset HEAD -- jenkins.yaml
git checkout -- jenkins.yaml

