#!/bin/bash
# Sync Unix users from Docker container to host machine
# This allows SSH access to the host, while keeping users in the container for permissions

set -e

CONTAINER_NAME="${1:-autolab}"
RAILS_CMD="cd /home/app/webapp && RAILS_ENV=production bundle exec"

echo "========================================="
echo "Sync Unix Users to Host"
echo "========================================="
echo "Container: $CONTAINER_NAME"
echo ""

# Get all staff users from Rails
echo "1. Getting staff users from database..."
STAFF_USERS=$(docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'User.joins(:course_user_data).where(course_user_data: { instructor: true }).or(User.joins(:course_user_data).where(course_user_data: { course_assistant: true })).distinct.pluck(:email).each { |e| puts UnixGroupManager.login_from_email(e) }'")

while IFS= read -r username; do
  [ -z "$username" ] && continue
  
  email=$(docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'puts User.find_by(email: \"$(grep -r $username)\")'")
  
  echo "   Processing: $username"
  
  # Check if user exists on host
  if id "$username" &>/dev/null; then
    echo "     ✓ User $username already exists on host"
  else
    echo "     Creating user $username on host..."
    useradd -m -s /bin/bash -c "$email" "$username" || echo "     ✗ Failed to create user"
  fi
  
  # Create .ssh directory
  if [ ! -d "/home/$username/.ssh" ]; then
    mkdir -p "/home/$username/.ssh"
    chmod 700 "/home/$username/.ssh"
    chown "$username:$username" "/home/$username/.ssh"
    echo "     ✓ Created .ssh directory"
  fi
  
  # Sync authorized_keys from container
  CONTAINER_KEY="/home/$username/.ssh/authorized_keys"
  HOST_KEY="/home/$username/.ssh/authorized_keys"
  
  if docker exec $CONTAINER_NAME bash -c "[ -f $CONTAINER_KEY ]" 2>/dev/null; then
    docker exec $CONTAINER_NAME bash -c "cat $CONTAINER_KEY" > "$HOST_KEY.tmp"
    mv "$HOST_KEY.tmp" "$HOST_KEY"
    chmod 600 "$HOST_KEY"
    chown "$username:$username" "$HOST_KEY"
    echo "     ✓ Synced SSH keys from container"
  else
    touch "$HOST_KEY"
    chmod 600 "$HOST_KEY"
    chown "$username:$username" "$HOST_KEY"
    echo "     ✓ Created empty authorized_keys (will be populated when key is added via web UI)"
  fi
done <<< "$STAFF_USERS"

echo ""
echo "========================================="
echo "Done!"
echo "========================================="
echo ""
echo "Next: Users can now SSH into the host, then access the container or course directories"

