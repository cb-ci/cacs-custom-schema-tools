# Why the Default Jenkins JCasC Schema Can't Enforce Policy

The [default schema](default-jenkins-schema.json) is auto-generated from Jenkins core and plugin Java classes. It validates that a CasC YAML file is *structurally valid* (right types, right shape) — it does not, and structurally cannot, validate that a configuration meets a company's security policy. Two concrete examples from the file itself:

* **`authorizationStrategy`** (`jenkins.model.Jenkins`) is an optional, polymorphic field: any valid authorization strategy — including permissive ones — satisfies the schema. There is no way to require that an `authorizationStrategy` be set at all, let alone restrict it to an approved strategy (e.g. role-based, not "anyone can do anything").
* **`sshHostKeyVerificationStrategy`** (`org.jenkinsci.plugins.gitclient.verifier.SshHostKeyVerificationStrategy`) accepts either `knownHostsFileVerificationStrategy` (secure) or `noHostKeyVerificationStrategy` (accepts any host key, effectively disabling verification) as equally valid `oneOf` options. A bundle that disables SSH host key verification passes validation just as cleanly as one that enforces it.

This is by design: the default schema mirrors the full, permissive API surface of Jenkins so any legitimate configuration validates. It has no concept of organizational policy — mandatory fields, restricted enums, or "this option is disallowed" — so it cannot fail a bundle for using an insecure-but-technically-valid setting. Enforcing rules like "an `authorizationStrategy` is required" or "only `knownHostsFileVerificationStrategy` is allowed" requires a curated custom schema (see below) with `required`, `enum`, and narrowed `oneOf`/`additionalProperties: false` constraints layered on top.

# Jenkins CasC Schema Comparison

| Feature | Default Schema (`casc-cb-default-schema/jenkins.json`) | Custom Schema (`casc-controller-custom-schema/jenkins-schema.json`) |
| :--- | :--- | :--- |
| **Origin / Purpose** | **Auto-generated / Comprehensive:** Represents the full API surface of a CloudBees CI Operations Center or Controller. | **Manually Curated / Targeted:** A simplified "whitelist" schema tailored for a specific managed controller. |
| **Scope (Root Properties)** | **Wide (~18 root keys):** Includes everything from `advisor`, `kube`, and `license` to `masterprovisioning`. | **Narrow (8 root keys):** Only includes `jenkins`, `beekeeper`, `support`, `globalCredentials`, `appearance`, `security`, `tool`, and `unclassified`. |
| **Strictness** | **High:** Uses `additionalProperties: false` globally to prevent any non-standard configuration keys. | **Moderate:** Frequently allows additional properties (missing `additionalProperties: false` in major sections). |
| **Mandatory Config** | **Optional:** Almost all fields are optional (default behavior), reflecting the flexibility of CasC. | **Enforced:** Uses extensive `required` lists at every level to mandate specific configurations (e.g., `proxy`, `authorizationStrategy`). |
| **Data Modeling** | **Literal:** Maps directly to internal Java classes; often uses simple `string` types for comma-separated lists. | **Structured:** Uses higher-level types where appropriate (e.g., `support.componentIds` is an `array` instead of a `string`). |
| **OC Features** | **Included:** Contains Operations Center specific keys like `remoteBundle`, `bundleStorageService`, and `cascAutoControllerProvisioning`. | **Excluded:** Stripped of all Operations Center specific configurations; strictly focused on the **Managed Controller** lifecycle. |
| **Validation Detail** | **Internal References:** Uses `$id` to point to deep internal Jenkins definitions (`#/definitions/...`). | **Explicit Patterns:** Uses standard JSON Schema validation and custom regex `pattern` fields for input validation (e.g., `proxy.testUrl`). |
| **Plugin Coverage** | **Global:** Validates hundreds of plugin-specific settings within the `unclassified` section. | **Selective:** Only provides validation for a specific subset of plugins (e.g., `email-ext`, `gitHubPluginConfig`). |

# Example 1: Jenkins JCasC Default Schema (Permissive)

By design, the [Jenkins JCasC Default Schema](casc-cb-default-schema/jenkins.json) is open and lacks strict enforcement for many fields. For example, it might not enforce specific proxy ports or URL formats. A bundle with an invalid port might pass static validation but cause the Jenkins instance to fail or log warnings at runtime.

```json
"proxy": {
  "type": "object",
  "properties": {
    ...
    "port": {
      "type": "integer"
    },
    "testUrl": {
      "type": "string"
    }
```

# Example 2: Custom Schema (Strict Enforcement)

A [customized schema](casc-cb-custom-schema/jenkins.json) can enforce strict rules, allowing validation to fail-fast. For instance, it can restrict proxy ports to a known set (e.g., 3128, 8080) and validate URL patterns.

```json
"proxy": {
  "type": "object",
  "properties": {
    ...
    "port": {
      "type": "integer",
      "enum": [
        3128,
        8080
      ]
    },
    "testUrl": {
      "type": "string",
      "pattern": "^https?:\\/\\/(?!-)(?:[A-Za-z0-9-]{1,63}\\.)+[A-Za-z0-9-]{2,63}$"
    }
```

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
