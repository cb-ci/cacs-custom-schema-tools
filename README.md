# Default architecture and docs

* <https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/set-up-managed-controller-with-service>

# Static validation

CloudBees Specific json schemas

* https://<CONTROLLER_URL>/manage/core-casc-schema-download/download/items.json
* https://<CONTROLLER_URL>/manage/core-casc-schema-download/download/rbac.json
* https://<CONTROLLER_URL>/manage/core-casc-schema-download/download/plugin-catalog.json
* https://<CONTROLLER_URL>/manage/core-casc-schema-download/download/plugin-catalog.json

All CloudBees yaml json schemas

* https://<CJOC_URL>/manage/core-casc-schema-download/

Jeniins yaml schema download

* https://<CONTROLLER_URL>/manage/configuration-as-code/schema

# Create Schema from yaml

```
OUT_DIR="$(pwd)/casc-controller-schema"
yq . jenkins.yaml  -o json | python3 -m genson - |jq . |tee  $OUT_DIR/jenkins-schema.json
yq . items.yaml  -o json | python3 -m genson - |jq . |tee $OUT_DIR/items-schema.json
yq . plugins.yaml  -o json | python3 -m genson - |jq . |tee $OUT_DIR/plugins-schema.json
yq . rbac.yaml  -o json | python3 -m genson - |jq . |tee $OUT_DIR/rbac-schema.json
yq . variables.yaml  -o json | python3 -m genson - |jq . |tee $OUT_DIR/variables-schema.json
yq . bundle.yaml  -o json | python3 -m genson - |jq . |tee $OUT_DIR/bundle-schema.json
```

```
IMAGE=${1:-caternberg/casc-schema-tools:arm64}
docker run --rm -v $(pwd):/work $IMAGE bash -c "yq . jenkins.yaml -o json | python3 -m genson - | jq . > jenkins-schema.json"
```

## Update schema version

```
genson input.json | jq '."$schema" = "http://json-schema.org/draft-07/schema#"' > output.json
```

# Static validation

## Default schemas

```
IMAGE=${1:-caternberg/casc-schema-tools:arm64}
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-cb-default-schema/items.json casc-controller/items.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-cb-default-schema/jenkins.json casc-controller/jenkins.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-cb-default-schema/plugins-v2.json casc-controller/plugins.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-cb-default-schema/rbac.json casc-controller/rbac.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-cb-default-schema/variables.json casc-controller/variables.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-cb-default-schema/bundle-descriptor.json casc-controller/bundle.yaml
```

## Custom Schemas

```
IMAGE=${1:-caternberg/casc-schema-tools:arm64}
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-controller-custom-schema/items-schema.json casc-controller/items.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-controller-custom-schema/jenkins-schema.json casc-controller/jenkins.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-controller-custom-schema/plugins-schema.json casc-controller/plugins.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-controller-custom-schema/rbac-schema.json casc-controller/rbac.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-controller-custom-schema/variables-schema.json casc-controller/variables.yaml
docker run --rm -v $(pwd):/work $IMAGE check-jsonschema --schemafile casc-controller-custom-schema/bundle-schema.json casc-controller/bundle.yaml
```

# CASC validation

```
{JOC_URL}/casc-bundle/raw-bundle-validation-log
${JOC_URL}/casc-bundle/pre-validate-bundle
${CBCI_INSTANCE_URL}/casc-bundle-mgnt/casc-bundle-validate
POST /casc-bundle/get-effective-bundle
```
