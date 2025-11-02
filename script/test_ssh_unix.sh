#!/bin/bash
# Quick testing script for SSH keys and Unix user/group management
# Usage: ./script/test_ssh_unix.sh [container-name]
# Default container name: autolab

CONTAINER_NAME="autolab"
RAILS_CMD="cd /home/app/webapp && RAILS_ENV=production bundle exec"

echo "========================================="
echo "SSH Key & Unix User/Group Management Test"
echo "========================================="
echo "Container: $CONTAINER_NAME"
echo ""

# 1. Check if container exists
echo "1. Checking container..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "   ✗ Container '$CONTAINER_NAME' not found!"
    echo "   Available containers:"
    docker ps --format '  - {{.Names}}'
    exit 1
fi
echo "   ✓ Container found"
echo ""

# 2. Check migration
echo "2. Checking SSH keys migration..."
docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'puts ActiveRecord::Base.connection.table_exists?(:ssh_keys) ? \"✓ SSH keys table exists\" : \"✗ SSH keys table missing\"'"
echo ""

# 3. Check system commands
echo "3. Checking system commands..."
docker exec $CONTAINER_NAME bash -c "which useradd && which groupadd && echo '✓ Unix commands available' || echo '✗ Unix commands unavailable'"
echo ""

# 4. Test UnixGroupManager
echo "4. Testing UnixGroupManager system detection..."
docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'puts \"System commands available: #{UnixGroupManager.system_commands_available?}\"; puts \"Should skip operations: #{UnixGroupManager.should_skip_operations?}\"'"
echo ""

# 5. List courses
echo "5. Listing courses (first 5)..."
docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'Course.limit(5).each { |c| puts \"  - #{c.name}\" }'"
echo ""

# 6. Test course group creation
echo "6. Testing course group creation..."
docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'course = Course.first; if course; group = UnixGroupManager.safe_group_name(course.name); puts \"  Course: #{course.name}\"; puts \"  → Group: #{group}\"; result = UnixGroupManager.ensure_group(group); puts \"  Group exists: #{result ? \"✓\" : \"✗\"}\"; end'"
echo ""

# 7. List Unix groups
echo "7. Listing Unix groups (first 10)..."
docker exec $CONTAINER_NAME bash -c "getent group | grep -E '^grp-|^[a-z0-9-]+:' | head -10 | cut -d: -f1 | sed 's/^/  - /'"
echo ""

# 8. List Unix users (staff)
echo "8. Listing Unix users (staff)..."
docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'User.joins(:course_user_data).where(course_user_data: { instructor: true }).or(User.joins(:course_user_data).where(course_user_data: { course_assistant: true })).distinct.limit(5).each { |u| username = UnixGroupManager.login_from_email(u.email); puts \"  - #{u.email} → #{username}\" }'"
echo ""

# 9. Test SSH key creation
echo "9. Testing SSH key creation (finding staff user)..."
docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'user = User.joins(:course_user_data).where(course_user_data: { instructor: true }).first || User.find_by(administrator: true); if user; puts \"  User: #{user.email}\"; is_staff = user.respond_to?(:staff?) ? user.staff? : (user.instructor? || user.course_assistant?); puts \"  Is staff: #{is_staff}\"; count = user.respond_to?(:ssh_keys) ? user.ssh_keys.count : 0; puts \"  SSH keys: #{count}\"; else; puts \"  ✗ No users found\"; end'"
echo ""

# 10. Check course directory permissions
echo "10. Checking course directory permissions..."
docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'course = Course.first; if course; dir = course.directory_path; if Dir.exist?(dir); system(\"ls -lad #{dir} 2>&1\"); else; puts \"  ✗ Directory #{dir} does not exist\"; end; end'"
echo ""

# 11. Test file permission enforcement
echo "11. Testing FilesystemEnforcer..."
docker exec $CONTAINER_NAME bash -c "$RAILS_CMD rails runner 'course = Course.first; if course && Dir.exist?(course.directory_path); FilesystemEnforcer.fix_tree(course.directory_path.to_s); puts \"  ✓ Permissions fixed for #{course.name}\"; else; puts \"  ✗ Course directory not found\"; end'"
echo ""

echo "========================================="
echo "Test Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Run bootstrap: docker exec $CONTAINER_NAME bash -c \"$RAILS_CMD rails runner script/bootstrap_course_groups.rb\""
echo "  2. Test SSH key via web UI: /users/:id/ssh_keys"
echo "  3. Check logs: docker exec $CONTAINER_NAME tail -f /home/app/webapp/log/production.log"
echo ""

