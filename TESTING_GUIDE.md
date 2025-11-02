# Testing Guide: SSH Keys & Unix User/Group Management

## Prerequisites

1. Find your Docker container name:
```bash
docker ps | grep autolab
# Look for container name (usually "autolab" or similar)
```

Set the container name as a variable for convenience:
```bash
CONTAINER_NAME="autolab"  # Replace with your actual container name
```

## 1. Database Migration

### Run the SSH keys migration:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails db:migrate"
```

### Verify migration:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'puts SshKey.connection.table_exists?(:ssh_keys) ? \"SSH keys table exists\" : \"SSH keys table missing\"'"
```

## 2. Bootstrap Course Groups (For Existing Courses)

### Run bootstrap script (dry-run first):
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb --dry-run"
```

### Run bootstrap script (apply changes):
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb"
```

### Run bootstrap for specific course:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb --course=\"COURSE-NAME\""
```

## 3. Test Unix User/Group Creation

### Check if a Unix group exists:
```bash
docker exec -it $CONTAINER_NAME getent group <group-name>
# Example: docker exec -it $CONTAINER_NAME getent group grp-15-122
```

### Check if a Unix user exists:
```bash
docker exec -it $CONTAINER_NAME id <username>
# Example: docker exec -it $CONTAINER_NAME id instructor
```

### List all Unix groups:
```bash
docker exec -it $CONTAINER_NAME getent group | grep -E "^grp-|^[a-z0-9-]+:" | head -20
```

### Check user's groups:
```bash
docker exec -it $CONTAINER_NAME id -nG <username>
# Example: docker exec -it $CONTAINER_NAME id -nG instructor
```

### List all users:
```bash
docker exec -it $CONTAINER_NAME getent passwd | grep -E ":/home/[a-z0-9_-]+:/" | cut -d: -f1
```

## 4. Test SSH Key Management via Rails Console

### Open Rails console:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails c"
```

### In Rails console, test SSH key creation:
```ruby
# Find a staff user (instructor or TA)
user = User.joins(:course_user_data).where(course_user_data: { instructor: true }).first
# Or: user = User.joins(:course_user_data).where(course_user_data: { course_assistant: true }).first

# Check if user is staff
puts "User is staff: #{user.staff?}"

# Create a test SSH key
test_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGKj9testtesttesttesttesttesttesttesttesttest haoyuy@andrew.cmu.edu"
ssh_key = user.ssh_keys.create(public_key: test_key)

# Check if key was created
puts "SSH key created: #{ssh_key.persisted?}"
puts "SSH key fingerprint: #{ssh_key.fingerprint}"

# Check if Unix user exists
username = UnixGroupManager.login_from_email(user.email)
puts "Unix username: #{username}"

# Check if user exists in system
system("id #{username} 2>&1")
```

### Test Unix user creation:
```ruby
# In Rails console
username = UnixGroupManager.login_from_email(user.email)
result = UnixGroupManager.ensure_user(username, email: user.email)
puts "User created/verified: #{result}"
```

### Test course group setup:
```ruby
# In Rails console
course = Course.first
result = UnixGroupManager.setup_course_group(course)
puts "Course group setup: #{result}"

# Verify group exists
group_name = UnixGroupManager.safe_group_name(course.name)
puts "Group name: #{group_name}"
system("getent group #{group_name}")
```

## 5. Test SSH Key Provisioning

### Check if SSH key is in authorized_keys:
```bash
# Get username from email
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'puts UnixGroupManager.login_from_email(\"user@example.com\")'"

# Then check authorized_keys
docker exec -it $CONTAINER_NAME cat /home/<username>/.ssh/authorized_keys
# Example: docker exec -it $CONTAINER_NAME cat /home/instructor/.ssh/authorized_keys
```

### Check .ssh directory permissions:
```bash
docker exec -it $CONTAINER_NAME ls -la /home/<username>/.ssh/
# Should show: drwx------ (700 permissions)
```

### Check authorized_keys permissions:
```bash
docker exec -it $CONTAINER_NAME ls -la /home/<username>/.ssh/authorized_keys
# Should show: -rw------- (600 permissions)
```

## 6. Test File Permissions

### Check course directory permissions:
```bash
docker exec -it $CONTAINER_NAME ls -lad /home/app/webapp/courses/<course-name>/
# Should show: drwxrws--- (2770 permissions) with correct group ownership
```

### Check file permissions in course directory:
```bash
docker exec -it $CONTAINER_NAME ls -la /home/app/webapp/courses/<course-name>/ | head -10
# Files should show: -rw-rw---- (660 permissions) with correct group ownership
```

### Test file permission enforcement:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'course = Course.first; FilesystemEnforcer.fix_tree(course.directory_path.to_s); puts \"Permissions fixed for #{course.name}\"'"
```

## 7. Test SSH Key UI Flow

### Create a test SSH key via Rails console:
```ruby
# In Rails console
user = User.find_by(email: "instructor@example.com")  # Replace with actual instructor email
test_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGKj9TESTKEYHERE1234567890abcdefghijk instructor@example.com"
ssh_key = user.ssh_keys.create(public_key: test_key)
puts "SSH key ID: #{ssh_key.id}"
puts "Fingerprint: #{ssh_key.fingerprint}"
```

### List all SSH keys for a user:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'user = User.find(1); puts \"SSH keys for #{user.email}:\"; user.ssh_keys.each { |k| puts \"  - #{k.key_type} (#{k.fingerprint[0..16]}...)\" }'"
```

### Delete a test SSH key:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'SshKey.where(id: KEY_ID).destroy_all'"
# Replace KEY_ID with actual key ID
```

## 8. Integration Testing

### Test complete flow: Add staff → Unix user created → SSH key added:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner '
course = Course.first
user = User.find_by(email: \"test-instructor@example.com\")
if user && course
  cud = course.course_user_data.find_or_initialize_by(user: user)
  cud.instructor = true
  cud.save
  
  UnixGroupManager.update_course_staff_membership(course, user, is_staff: true)
  username = UnixGroupManager.login_from_email(user.email)
  puts \"Unix user: #{username}\"
  system(\"id #{username} 2>&1\")
  
  test_key = \"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGKj9testtesttesttesttesttesttesttesttesttest test@example.com\"
  ssh_key = user.ssh_keys.create(public_key: test_key)
  puts \"SSH key created: #{ssh_key.persisted?}\"
end
'"
```

### Test file permissions after file operations:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner '
course = Course.first
if course
  dir = course.directory_path
  test_file = File.join(dir, \"test_permissions.txt\")
  File.write(test_file, \"test content\")
  FilesystemEnforcer.fix_path(test_file)
  
  puts \"File: #{test_file}\"
  system(\"ls -la #{test_file}\")
  
  File.delete(test_file) if File.exist?(test_file)
end
'"
```

## 9. Verify System Commands Availability

### Check if Unix commands are available:
```bash
docker exec -it $CONTAINER_NAME which useradd
docker exec -it $CONTAINER_NAME which groupadd
docker exec -it $CONTAINER_NAME which usermod
docker exec -it $CONTAINER_NAME which gpasswd
```

### Test system command detection:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'puts \"System commands available: #{UnixGroupManager.system_commands_available?}\"; puts \"Should skip operations: #{UnixGroupManager.should_skip_operations?}\"'"
```

## 10. Test Course Creation Flow

### Create a test course via Rails console:
```ruby
# In Rails console
course = Course.create!(
  name: "test-course-123",
  display_name: "Test Course",
  semester: "Fall 2025",
  start_date: Date.today,
  end_date: Date.today + 3.months,
  late_slack: 60,
  grace_days: 3,
  late_penalty: Penalty.first || Penalty.create!(kind: "points", value: 0),
  version_penalty: Penalty.first || Penalty.create!(kind: "points", value: 0)
)

# Check if Unix group was created
group_name = UnixGroupManager.safe_group_name(course.name)
system("getent group #{group_name}")
```

## 11. Test Permission Enforcement on Existing Files

### Fix permissions for all courses:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner '
Course.find_each do |course|
  dir = course.directory_path
  if Dir.exist?(dir)
    puts \"Fixing permissions for #{course.name}...\"
    FilesystemEnforcer.fix_tree(dir.to_s)
    system(\"ls -lad #{dir}\")
  end
end
'"
```

## 12. Verify User Isolation

### Test that instructor can only access their course directories:
```bash
# Get username
USERNAME="instructor"  # Replace with actual username

# Try to list courses directory
docker exec -it $CONTAINER_NAME sudo -u $USERNAME ls -la /home/app/webapp/courses/

# Try to access a course directory
docker exec -it $CONTAINER_NAME sudo -u $USERNAME ls -la /home/app/webapp/courses/<course-name>/

# Try to access another course directory (should fail)
docker exec -it $CONTAINER_NAME sudo -u $USERNAME ls -la /home/app/webapp/courses/<other-course-name>/ 2>&1
```

## 13. Check Logs for Unix Operations

### View Rails logs for Unix operations:
```bash
docker exec -it $CONTAINER_NAME tail -f /home/app/webapp/log/production.log | grep -E "Unix|SSH|user|group"
```

### View all recent logs:
```bash
docker exec -it $CONTAINER_NAME tail -n 100 /home/app/webapp/log/production.log
```

## 14. Cleanup Test Data

### Remove test SSH keys:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'SshKey.where(\"comment LIKE ?\", \"%test%\").destroy_all'"
```

### Remove test Unix users (if needed):
```bash
# WARNING: Only remove if user is no longer staff in any course
docker exec -it $CONTAINER_NAME userdel -r <username>
```

## Quick Test Script

Run this comprehensive test in one go:

```bash
CONTAINER_NAME="autolab"  # Change to your container name

echo "=== Testing SSH Key & Unix User Management ==="
echo ""
echo "1. Checking migration..."
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'puts SshKey.connection.table_exists?(:ssh_keys) ? \"✓ SSH keys table exists\" : \"✗ SSH keys table missing\"'"

echo ""
echo "2. Checking system commands..."
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'puts UnixGroupManager.system_commands_available? ? \"✓ System commands available\" : \"✗ System commands unavailable\"'"

echo ""
echo "3. Listing courses..."
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'Course.limit(5).each { |c| puts \"  - #{c.name}\" }'"

echo ""
echo "4. Testing Unix group creation for first course..."
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'course = Course.first; if course; group = UnixGroupManager.safe_group_name(course.name); puts \"  Course: #{course.name} → Group: #{group}\"; result = UnixGroupManager.ensure_group(group); puts \"  Group exists: #{result ? \"✓\" : \"✗\"}\"; end'"

echo ""
echo "=== Testing Complete ==="
```

## Common Issues & Solutions

### Issue: "No such file or directory - useradd"
**Solution:** This happens on macOS. On Linux/Docker, ensure the container has `useradd`:
```bash
docker exec -it $CONTAINER_NAME which useradd
```

### Issue: Permission denied when accessing course directories
**Solution:** Run bootstrap script to set up groups and add users:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb"
```

### Issue: SSH keys saved but not in authorized_keys
**Solution:** Check if Unix user exists and has home directory:
```bash
docker exec -it $CONTAINER_NAME id <username>
docker exec -it $CONTAINER_NAME ls -la /home/<username>/.ssh/
```

