# Complete Autolab Filesystem Setup Guide

## Overview

This guide sets up:
1. **System user `autolab`**: For the web application and file ownership
2. **Unix users on host**: For instructors to SSH in
3. **Proper file permissions**: Course directories protected by groups

## Prerequisites

- Root access on host machine
- Docker container running Autolab
- Bootstrap script completed in container (creates course groups)

## Step 1: Create System User and Fix Ownership

Run on the host machine:

```bash
# Make script executable
chmod +x script/setup_host_system_user.sh

# Run setup
sudo ./script/setup_host_system_user.sh
```

This will:
- Create system user `autolab`
- Move `/home/user9999/autolab-docker` → `/home/autolab/docker`
- Set proper ownership (`autolab:autolab`)
- Make parent directories navigable

## Step 2: Update Docker Compose (If You Moved Files)

If files were moved, update `docker-compose.yml`:

```yaml
volumes:
  # Update paths if you moved from user9999 to autolab
  - /home/autolab/docker/Autolab:/home/app/webapp
  # Or keep relative path if docker-compose is in autolab-docker directory
```

## Step 3: Create Unix Users on Host

Create instructor Unix users on host (for SSH):

```bash
# Make script executable
chmod +x script/create_host_instructor_users.sh

# Run (syncs users from container to host)
sudo ./script/create_host_instructor_users.sh
```

This will:
- Get all staff users from database
- Create matching Unix users on host
- Sync SSH keys from container (if any)
- Match UIDs with container users (for proper permissions)

## Step 4: Verify Setup

### Check System User

```bash
id autolab
ls -lad /home/autolab/docker/Autolab
```

### Check Instructor Users

```bash
# List created users
id haoyuy
id iliano

# Check SSH setup
ls -la /home/haoyuy/.ssh/
```

### Check Course Permissions

```bash
# Check course directory permissions
ls -lad /home/autolab/docker/Autolab/courses/15-122/
# Should show: drwxrws--- root:grp-15-122 or similar
```

### Test Navigation

As an instructor user:

```bash
su - haoyuy
cd /home/autolab/docker/Autolab/courses/
ls -la 15-122/  # Should work if user is in course group
```

## Step 5: Add SSH Keys Via Web UI

1. Log into Autolab web interface
2. Go to `/users/<id>/ssh_keys`
3. Add SSH public key
4. Key will be provisioned to:
   - Container: `/home/<username>/.ssh/authorized_keys`
   - Host: `/home/<username>/.ssh/authorized_keys` (manually sync or via script)

## Step 6: Sync SSH Keys (Automated - Future Enhancement)

For now, SSH keys added via web UI are in container. To sync to host:

```bash
# Manual sync (or run create_host_instructor_users.sh again)
docker exec autolab bash -c "cat /home/haoyuy/.ssh/authorized_keys" > /home/haoyuy/.ssh/authorized_keys
chown haoyuy:haoyuy /home/haoyuy/.ssh/authorized_keys
chmod 600 /home/haoyuy/.ssh/authorized_keys
```

## Verification Checklist

- [ ] System user `autolab` exists
- [ ] Files owned by `autolab:autolab` or appropriate group
- [ ] Parent directories are navigable (`755` permissions)
- [ ] Instructor Unix users exist on host
- [ ] Course directories have group ownership (`drwxrws---`)
- [ ] Instructor users can SSH into host
- [ ] Instructor users can access their course directories
- [ ] SSH keys sync between container and host

## Troubleshooting

### Issue: "Permission denied" accessing autolab directory

```bash
# Make parent directories readable
chmod 755 /home/autolab
chmod 755 /home/autolab/docker
chmod 755 /home/autolab/docker/Autolab
chmod 755 /home/autolab/docker/Autolab/courses
```

### Issue: UID mismatch between container and host

```bash
# Check UIDs
docker exec autolab bash -c "id -u haoyuy"
id -u haoyuy

# If different, recreate user on host with matching UID
userdel haoyuy
rm -rf /home/haoyuy
useradd -u <CONTAINER_UID> -m -s /bin/bash haoyuy
```

### Issue: Course directory not accessible

```bash
# Check group membership
id haoyuy  # Should show course group

# Check directory permissions
ls -lad /home/autolab/docker/Autolab/courses/15-122/
# Should be: drwxrws--- root:grp-15-122

# Re-run bootstrap to fix permissions
docker exec -u root autolab bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb"
```

## File Structure Summary

```
/home/autolab/                          # System user (autolab:autolab)
├── docker/                             # Docker compose directory
│   └── Autolab/                        # Autolab application
│       ├── app/                        # Rails app
│       └── courses/                    # Course directories (root:<course-group>)
│           └── 15-122/                 # drwxrws--- root:grp-15-122

/home/haoyuy/                           # Instructor user (haoyuy:haoyuy)
├── .ssh/
│   └── authorized_keys                 # SSH key for login

/home/iliano/                           # Another instructor
└── .ssh/
    └── authorized_keys
```

## Next Steps

1. **Add SSH keys** via web UI
2. **Test SSH access** from instructor machines
3. **Verify file isolation** (instructors only see their courses)
4. **Set up automated sync** for SSH keys (future enhancement)

