#!/bin/bash
# Setup host system user and fix file ownership
# This should be run on the host machine (not in Docker)

set -e

echo "========================================="
echo "Autolab Host System Setup"
echo "========================================="
echo ""

# 1. Create system user for Autolab
echo "1. Creating system user 'autolab'..."
if id "autolab" &>/dev/null; then
    echo "   ✓ User 'autolab' already exists"
else
    useradd -r -m -s /bin/bash -d /home/autolab -c "Autolab System User" autolab
    echo "   ✓ Created system user 'autolab'"
fi
echo ""

# 2. Fix ownership of autolab-docker directory
echo "2. Fixing ownership of autolab-docker directory..."
if [ -d "/home/user9999/autolab-docker" ]; then
    echo "   Moving from user9999 to autolab..."
    mv /home/user9999/autolab-docker /home/autolab/docker
    chown -R autolab:autolab /home/autolab/docker
    echo "   ✓ Moved and set ownership to autolab:autolab"
elif [ -d "/home/autolab/docker" ]; then
    chown -R autolab:autolab /home/autolab/docker
    echo "   ✓ Fixed ownership to autolab:autolab"
else
    echo "   ⚠ Warning: Could not find autolab-docker directory"
fi
echo ""

# 3. Set proper permissions on parent directories
echo "3. Setting permissions on parent directories..."
chmod 755 /home/autolab
chmod 755 /home/autolab/docker 2>/dev/null || true
chmod 755 /home/autolab/docker/Autolab 2>/dev/null || true
chmod 755 /home/autolab/docker/Autolab/courses 2>/dev/null || true
echo "   ✓ Parent directories are now navigable"
echo ""

# 4. Create staff group (optional, for broader access)
echo "4. Creating autolab-staff group..."
if getent group autolab-staff > /dev/null 2>&1; then
    echo "   ✓ Group 'autolab-staff' already exists"
else
    groupadd autolab-staff
    echo "   ✓ Created group 'autolab-staff'"
fi
echo ""

# 5. Show current setup
echo "5. Current setup:"
echo "   System user: $(id autolab)"
echo "   Autolab directory: $(ls -lad /home/autolab 2>/dev/null || echo 'Not found')"
echo ""

echo "========================================="
echo "Host Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Update docker-compose.yml volume paths if you moved files"
echo "  2. Create Unix users for instructors on host (for SSH)"
echo "  3. Run bootstrap script to set course group permissions"
echo ""

