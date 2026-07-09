#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SRC="$SCRIPT_DIR/plugin-src"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"
JAR_FILE="$OUTPUT_DIR/poc-plugin.jar"

if ! command -v javac &> /dev/null; then
    echo "[-] javac not found. Please install JDK 17+."
    exit 1
fi

BUILD_DIR=$(mktemp -d)
STUBS_COMPILE_DIR="$BUILD_DIR/stubs_compile"
STUBS_OUT="$BUILD_DIR/stubs_out"
CLASSES_OUT="$BUILD_DIR/classes_out"
echo "[*] Build dir: $BUILD_DIR"

mkdir -p "$STUBS_COMPILE_DIR/org/pf4j"
mkdir -p "$STUBS_COMPILE_DIR/org/slf4j"
mkdir -p "$STUBS_COMPILE_DIR/jakarta/annotation"
mkdir -p "$CLASSES_OUT"

# ====== Stub sources ======
cat > "$STUBS_COMPILE_DIR/org/pf4j/Plugin.java" << 'EOF'
package org.pf4j;
public class Plugin {
    public Plugin(PluginWrapper wrapper) {}
    public void start() {}
    public void stop() {}
}
EOF

cat > "$STUBS_COMPILE_DIR/org/pf4j/PluginWrapper.java" << 'EOF'
package org.pf4j;
public class PluginWrapper {
    public String getPluginId() { return ""; }
}
EOF

cat > "$STUBS_COMPILE_DIR/org/pf4j/Extension.java" << 'EOF'
package org.pf4j;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Extension { int ordinal() default 0; }
EOF

cat > "$STUBS_COMPILE_DIR/org/slf4j/Logger.java" << 'EOF'
package org.slf4j;
public interface Logger {
    void info(String s); void info(String s, Object o1); void error(String s);
    void error(String s, Throwable t); void error(String s, Object o1);
    void warn(String s); void warn(String s, Object o1);
}
EOF

cat > "$STUBS_COMPILE_DIR/org/slf4j/LoggerFactory.java" << 'EOF'
package org.slf4j;
public class LoggerFactory { public static Logger getLogger(Class<?> c) { return null; } }
EOF

cat > "$STUBS_COMPILE_DIR/jakarta/annotation/PostConstruct.java" << 'EOF'
package jakarta.annotation;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface PostConstruct {}
EOF

# ====== Compile stubs ======
echo "[*] Compiling stubs..."
javac -d "$STUBS_OUT" "$STUBS_COMPILE_DIR"/org/pf4j/*.java \
    "$STUBS_COMPILE_DIR"/org/slf4j/*.java \
    "$STUBS_COMPILE_DIR"/jakarta/annotation/*.java

# ====== Compile PoC classes (clean, no stubs in output) ======
echo "[*] Compiling PoC classes..."
javac -cp "$STUBS_OUT" -d "$CLASSES_OUT" \
    "$PLUGIN_SRC/run/halo/app/plugin/PocPlugin.java" \
    "$PLUGIN_SRC/run/halo/app/plugin/PocExtension.java"

echo "[*] Compilation OK."

# ====== META-INF/plugin-components.idx for Halo SpringComponentsFinder ======
mkdir -p "$CLASSES_OUT/META-INF"
echo "run.halo.app.plugin.PocExtension" > "$CLASSES_OUT/META-INF/plugin-components.idx"

# ====== Create JAR ======
echo "[*] Creating JAR..."
cd "$CLASSES_OUT"
jar cf "$JAR_FILE" .

cd "$PLUGIN_SRC"
jar uf "$JAR_FILE" plugin.yaml

# ====== Verify ======
echo ""
echo "[*] JAR contents:"
jar tf "$JAR_FILE"

echo ""
echo "[+] Plugin JAR: $JAR_FILE ($(wc -c < "$JAR_FILE") bytes)"
rm -rf "$BUILD_DIR"
