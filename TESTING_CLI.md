# Quick Testing CLI Commands for Docker

## Prerequisites

Set your container name:
```bash
CONTAINER_NAME="autolab"  # Change to your actual container name
```

## 1. Run Migration

```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails db:migrate"
```

## 2. Bootstrap Course Groups

```bash
# Dry-run first
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb --dry-run"

# Apply changes
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb"
```

## 3. Check SSH Keys Table

```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'require \"app/models/ssh_key\"; puts SshKey.connection.table_exists?(:ssh_keys) ? \"✓ Table exists\" : \"✗ Table missing\"'"
```

## 4. Test Unix Group Creation

```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'require \"app/services/unix_group_manager\"; course = Course.first; if course; group = UnixGroupManager.safe_group_name(course.name); puts \"Course: #{course.name} → Group: #{group}\"; UnixGroupManager.ensure_group(group); system(\"getent group #{group}\"); end'"
```

## 5. Create a Test SSH Key

```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner '
require \"app/models/ssh_key\"
require \"app/services/unix_group_manager\"

user = User.joins(:course_user_data).where(course_user_data: { instructor: true }).first || User.find_by(administrator: true)
if user
  puts \"User: #{user.email}\"
  test_key = \"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGKj9TESTKEYHERE1234567890abcdefghijk test@example.com\"
  ssh_key = user.ssh_keys.create(public_key: test_key)
  if ssh_key.persisted?
    puts \"✓ SSH key created: #{ssh_key.fingerprint[0..16]}...\"
    username = UnixGroupManager.login_from_email(user.email)
    puts \"Unix username: #{username}\"
    system(\"id #{username} 2>&1\")
    system(\"ls -la /home/#{username}/.ssh/authorized_keys 2>&1\") if File.exist?(\"/home/#{username}/.ssh/authorized_keys\")
  else
    puts \"✗ Failed: #{ssh_key.errors.full_messages.join(\", \")}\"
  end
else
  puts \"✗ No staff user found\"
end
'"
```

## 6. List All SSH Keys

```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'require \"app/models/ssh_key\"; SshKey.all.each { |k| puts \"#{k.user.email}: #{k.key_type} (#{k.fingerprint[0..16]}...)\" }'"
```

## 7. Check Unix Users and Groups

```bash
# List all Unix groups (course groups)
docker exec -it $CONTAINER_NAME bash -c "getent group | grep -E '^grp-|^[a-z0-9-]+:' | cut -d: -f1"

# Check if a specific user exists
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'require \"app/services/unix_group_manager\"; user = User.first; username = UnixGroupManager.login_from_email(user.email); puts \"Email: #{user.email} → Username: #{username}\"; system(\"id #{username} 2>&1\")'"
```

## 8. Check Course Directory Permissions

```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner '
course = Course.first
if course
  dir = course.directory_path
  puts \"Course: #{course.name}\"
  system(\"ls -lad #{dir}\")
  system(\"ls -la #{dir} | head -5\")
end
'"
```

## 9. Fix Permissions for All Courses

```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner '
require \"app/services/filesystem_enforcer\"
Course.find_each do |course|
  dir = course.directory_path
  if Dir.exist?(dir)
    puts \"Fixing permissions for #{course.name}...\"
    FilesystemEnforcer.fix_tree(dir.to_s)
  end
end
puts \"Done!\"
'"
```

## 10. Test Complete Flow: Add Staff → Create User → Add SSH Key

```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner '
require \"app/models/ssh_key\"
require \"app/services/unix_group_manager\"

# Find or create a test user
user = User.find_by(email: \"test-instructor@example.com\") || User.first
course = Course.first

if user && course
  puts \"1. Adding user as instructor...\"
  cud = course.course_user_data.find_or_initialize_by(user: user)
  cud.instructor = true
  cud.save
  
  puts \"2. Setting up Unix user and group...\"
  UnixGroupManager.update_course_staff_membership(course, user, is_staff: true)
  username = UnixGroupManager.login_from_email(user.email)
  puts \"   Username: #{username}\"
  system(\"id #{username} 2>&1\")
  
  puts \"3. Creating SSH key...\"
  test_key = \"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGKj9TESTKEYHERE1234567890abcdefghijk test@example.com\"
  ssh_key = user.ssh_keys.create(public_key: test_key)
  if ssh_key.persisted?
    puts \"   ✓ SSH key created\"
    system(\"ls -la /home/#{username}/.ssh/authorized_keys 2>&1\")
  else
    puts \"   ✗ Failed: #{ssh_key.errors.full_messages.join(\", \")}\"
  end
end
'"
```

## 11. Delete Test SSH Key

```bash
# First, find the key ID
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'require \"app/models/ssh_key\"; SshKey.where(\"comment LIKE ? OR public_key LIKE ?\", \"%test%\", \"%TEST%\").each { |k| puts \"ID: #{k.id}, User: #{k.user.email}\" }'"

# Then delete (replace KEY_ID)
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner 'require \"app/models/ssh_key\"; SshKey.find(KEY_ID).destroy; puts \"Deleted\"'"
```

## 12. Verify User Isolation

```bash
# Get username
USERNAME="instructor"  # Replace with actual username

# Try to access a course directory
docker exec -it $CONTAINER_NAME sudo -u $USERNAME ls -la /home/app/webapp/courses/<course-name>/

# Should only work if user is in the course group
```

## 13. Restart Passenger (After Code Changes)

```bash
docker exec -it $CONTAINER_NAME passenger-config restart-app /home/app/webapp
```

## 14. View Logs

```bash
# Rails logs
docker exec -it $CONTAINER_NAME tail -f /home/app/webapp/log/production.log

# Filter for Unix/SSH operations
docker exec -it $CONTAINER_NAME tail -f /home/app/webapp/log/production.log | grep -E "Unix|SSH|user|group"
```

## Quick Test All

Run the automated test script:
```bash
./script/test_ssh_unix.sh autolab
```

## Common Issues

### Issue: "uninitialized constant"
**Solution:** Restart Passenger to reload code:
```bash
docker exec -it $CONTAINER_NAME passenger-config restart-app /home/app/webapp
```

### Issue: Permission denied
**Solution:** Run bootstrap script:
```bash
docker exec -it $CONTAINER_NAME bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb"
```

### Issue: User not found
**Solution:** Ensure user is staff (instructor or TA) in at least one course.

