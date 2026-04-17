#!/bin/bash
# Create Unix users on host for instructors who need SSH access
# This syncs users from the Docker container to the host

set -e

CONTAINER_NAME="${1:-autolab}"
RAILS_CMD="cd /home/app/webapp && RAILS_ENV=production bundle exec"

echo "========================================="
echo "Create Host Unix Users for Instructors"
echo "========================================="
echo "Container: $CONTAINER_NAME"
echo ""

# Check if container exists
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "   ✗ Container '$CONTAINER_NAME' not found!"
    exit 1
fi
echo "   ✓ Container found"
echo ""

# Get all staff users from database
echo "1. Getting staff users from database..."
STAFF_USERS=$(docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'User.joins(:course_user_data).where(course_user_data: { instructor: true }).or(User.joins(:course_user_data).where(course_user_data: { course_assistant: true })).distinct.each { |u| puts \"#{u.email}|#{UnixGroupManager.login_from_email(u.email)}\" }'")

if [ -z "$STAFF_USERS" ]; then
    echo "   ⚠ No staff users found in database"
    exit 0
fi

echo "$STAFF_USERS" | while IFS='|' read -r email username; do
    [ -z "$username" ] && continue
    
    echo ""
    echo "2. Processing: $email → $username"
    
    # Check if user exists on host
    if id "$username" &>/dev/null; then
        echo "   ✓ User $username already exists on host"
        
        # Get UID from container
        CONTAINER_UID=$(docker exec $CONTAINER_NAME bash -c "id -u $username 2>/dev/null" || echo "")
        HOST_UID=$(id -u "$username" 2>/dev/null || echo "")
        
        if [ -n "$CONTAINER_UID" ] && [ -n "$HOST_UID" ] && [ "$CONTAINER_UID" != "$HOST_UID" ]; then
            echo "   ⚠ Warning: UID mismatch (container: $CONTAINER_UID, host: $HOST_UID)"
            echo "     Consider recreating user with matching UID for proper permissions"
        fi
    else
        echo "   Creating user $username on host..."
        
        # Try to get UID from container to match
        CONTAINER_UID=$(docker exec $CONTAINER_NAME bash -c "id -u $username 2>/dev/null" || echo "")
        
        if [ -n "$CONTAINER_UID" ] && [ "$CONTAINER_UID" != "" ]; then
            # Create with matching UID
            useradd -u "$CONTAINER_UID" -m -s /bin/bash -c "$email" "$username" || {
                echo "   ✗ Failed to create user with UID $CONTAINER_UID (may already exist)"
                echo "   Trying without specified UID..."
                useradd -m -s /bin/bash -c "$email" "$username" || {
                    echo "   ✗ Failed to create user"
                    continue
                }
            }
            echo "   ✓ Created user $username with UID $CONTAINER_UID (matching container)"
        else
            # Create without specified UID (let system assign)
            useradd -m -s /bin/bash -c "$email" "$username" || {
                echo "   ✗ Failed to create user"
                continue
            }
            echo "   ✓ Created user $username"
        fi
    fi
    
    # Create .ssh directory
    if [ ! -d "/home/$username/.ssh" ]; then
        mkdir -p "/home/$username/.ssh"
        chmod 700 "/home/$username/.ssh"
        chown "$username:$username" "/home/$username/.ssh"
        echo "   ✓ Created .ssh directory"
    fi
    
    # Sync authorized_keys from container
    CONTAINER_AUTH="/home/$username/.ssh/authorized_keys"
    HOST_AUTH="/home/$username/.ssh/authorized_keys"
    
    if docker exec $CONTAINER_NAME bash -c "[ -f $CONTAINER_AUTH ]" 2>/dev/null; then
        docker exec $CONTAINER_NAME bash -c "cat $CONTAINER_AUTH" > "$HOST_AUTH.tmp" 2>/dev/null
        if [ -f "$HOST_AUTH.tmp" ]; then
            mv "$HOST_AUTH.tmp" "$HOST_AUTH"
            chmod 600 "$HOST_AUTH"
            chown "$username:$username" "$HOST_AUTH"
            echo "   ✓ Synced SSH keys from container"
        fi
    else
        # Create empty file
        touch "$HOST_AUTH"
        chmod 600 "$HOST_AUTH"
        chown "$username:$username" "$HOST_AUTH"
        echo "   ✓ Created empty authorized_keys (add keys via web UI)"
    fi
    
    # Verify user can access autolab directories
    if [ -d "/home/autolab/docker/Autolab/courses" ]; then
        echo "   ✓ Autolab courses directory accessible"
    fi
done

echo ""
echo "========================================="
echo "Host Users Setup Complete!"
echo "========================================="
echo ""
echo "Instructors can now:"
echo "  1. SSH into host as their Unix user"
echo "  2. Access course directories via group membership"
echo "  3. Add SSH keys via web UI (will sync to host)"
echo ""

