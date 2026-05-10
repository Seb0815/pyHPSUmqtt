#!/bin/bash

SHARE_DIR="/usr/share/pyHPSU/"
CONF_DIR="/etc/pyHPSU"
BIN_DIR="/usr/bin/"
PACKAGE_DIR="/usr/share/doc/packages/pyHPSU"
DIST_DIR="/usr/lib/python3/dist-packages/HPSU"
BACKUP_DIR="/tmp/pyHPSU_backup_$(date +%Y%m%d_%H%M%S)"

echo "=== pyHPSU Update ==="

# check if pyHPSU is installed
if [ ! -f "$BIN_DIR/pyHPSU.py" ]; then
    echo "ERROR: pyHPSU is not installed. Run install.sh first."
    exit 1
fi

# backup config
echo "Backing up configuration to $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
if [ -d "$CONF_DIR" ]; then
    cp -a "$CONF_DIR" "$BACKUP_DIR/pyHPSU_conf"
fi

# update command definitions (translations + json)
echo "Updating command definitions ..."
cp etc/pyHPSU/commands* "$CONF_DIR/"

# config: don't overwrite, just place .new for manual merge
if [ -f "$CONF_DIR/pyhpsu.conf" ]; then
    cp etc/pyHPSU/pyhpsu.conf "$CONF_DIR/pyhpsu.conf.new"
    echo "NOTE: New default config saved as $CONF_DIR/pyhpsu.conf.new"
    echo "      Your existing $CONF_DIR/pyhpsu.conf was NOT changed."
    # show diff if available
    if command -v diff &>/dev/null; then
        DIFF=$(diff -u "$CONF_DIR/pyhpsu.conf" "$CONF_DIR/pyhpsu.conf.new" 2>/dev/null)
        if [ -n "$DIFF" ]; then
            echo ""
            echo "--- Config differences (your config vs. new default) ---"
            echo "$DIFF"
            echo "--- End of differences ---"
            echo ""
        else
            echo "      (No differences found, configs are identical.)"
            rm -f "$CONF_DIR/pyhpsu.conf.new"
        fi
    fi
else
    cp etc/pyHPSU/pyhpsu.conf "$CONF_DIR/"
    echo "No existing config found, installed default config."
fi

# update python modules
echo "Updating HPSU modules ..."
cp -r HPSU/* "$DIST_DIR/"

# update contrib scripts
echo "Updating contrib scripts ..."
cp -r contrib "$DIST_DIR/"

# update resources
echo "Updating resources ..."
cp -r resources/* "$SHARE_DIR"

# update executables
echo "Updating executables ..."
cp pyHPSU.py "$BIN_DIR/"
cp pyHPSUd.py "$BIN_DIR/"
chmod a+x "$BIN_DIR/pyHPSU.py"
chmod a+x "$BIN_DIR/pyHPSUd.py"

echo ""
echo "=== pyHPSU Update done ==="
echo "Config backup: $BACKUP_DIR"
echo ""
echo "If you run pyHPSU as a systemd service, restart it:"
echo "  sudo systemctl restart hpsu.service"
