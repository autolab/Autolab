# Autolab File System Permission & SSH Key Management - Implementation Report

**Author**: Haoyu Yang  
**Team**: Autolab @ Carnegie Mellon University  
**Period**: Fall 2025 (Sept → Nov)  
**Status**: ✅ Complete

---

## Executive Summary

We've successfully implemented a comprehensive file system permission and SSH key management system for Autolab that provides:

- **Per-course Unix groups** for access control
- **On-demand Unix user creation** (users created only when SSH keys are added)
- **SSH key management** via web UI
- **Automatic file permission enforcement** using Unix groups and setgid bit
- **Docker integration** that creates users/groups on host (not container)
- **Group-based file isolation** (instructors only access their courses)

---

## 1. Problem Statement

### Legacy Issues

- All course files stored under `courses/` with globally readable permissions
- No per-course Unix groups, no per-user identity mapping
- Instructors and TAs all ran as the same Unix user
- Cross-course leakage risk
- No way to provide instructors direct SSH access with proper isolation

### Requirements

1. Per-course Unix groups matching course directories
2. Correct file ownership and permissions (`drwxrws---`, `-rw-rw----`)
3. Integration with Rails for automated management
4. SSH key authentication for instructors
5. Container-safe (works with Docker)

---

## 2. Solution Overview

### Architecture

**On-Demand User Creation Model:**
- ✅ Unix groups created when courses are created
- ❌ Unix users NOT created automatically when staff is added
- ✅ Unix users created ONLY when staff adds their first SSH key via web UI
- ✅ User automatically added to all course groups they're staff in

**File Permissions:**
- Course directories: `drwxrws---` (2770) - owned by `root:<course-group>`
- Course files: `-rw-rw----` (660) - owned by `root:<course-group>`
- Setgid bit ensures new files inherit group ownership

**Docker Integration:**
- Bind mount host system files (`/etc/passwd`, `/etc/group`, `/home`)
- Container operations affect host (users/groups created on host)
- Permission changes persist (bind mounts share same inodes)

---

## 3. Implementation Details

### 3.1 Database Schema

**Migration**: `db/migrate/20251102150304_create_ssh_keys.rb`

- `ssh_keys` table with fields: `user_id`, `public_key`, `key_type`, `fingerprint`, `comment`, `active`
- Unique fingerprint constraint to prevent duplicate keys
- Indexed for fast lookups

### 3.2 Core Services

**`app/services/unix_group_manager.rb`** (447 lines)
- `safe_group_name(course_name)`: Creates safe Unix group names (max 32 chars, prefix `grp-` if needed)
- `login_from_email(email)`: Creates safe Unix usernames from email addresses
- `ensure_group(group_name)`: Creates Unix group if doesn't exist
- `ensure_user(username, email)`: Creates Unix user with locked password (`-p "*"`)
- `setup_user_home(username)`: Creates `.ssh` directory with proper permissions
- `provision_ssh_key(username, public_key)`: Adds key to `authorized_keys`
- `deprovision_ssh_key(username, fingerprint)`: Removes key from `authorized_keys`
- `update_course_staff_membership(course, user, is_staff)`: Updates group membership (only if user exists)
- `system_commands_available?`: Detects Linux environment
- `should_skip_operations?`: Skips operations in development (macOS) unless `ENABLE_UNIX_OPS` is set

**`app/services/filesystem_enforcer.rb`** (80 lines)
- `fix_path(path)`: Sets correct ownership and permissions for a file/directory
- `fix_tree(root)`: Recursively fixes permissions for entire directory tree
- `inferred_group(path)`: Determines course group from file path
- Uses `File.chown` and `File.chmod` which work correctly with bind mounts

### 3.3 Models

**`app/models/ssh_key.rb`** (152 lines)
- Validates SSH key format (SSH-RSA, SSH-ED25519, ECDSA)
- Extracts fingerprint, key type, comment from public key
- `before_save :parse_key_metadata`: Extracts key metadata
- `after_save :provision_key`: Creates Unix user (if doesn't exist) and provisions SSH key
- `after_destroy :deprovision_key`: Removes SSH key
- **On SSH key add**: Creates Unix user and adds to all course groups user is staff in

**`app/models/user.rb`**
- Added `has_many :ssh_keys`
- Added `staff?` method (instructor or TA)
- Added `course_assistant?` method

**`app/models/course.rb`**
- Calls `UnixGroupManager.setup_course_group` on course creation
- Creates Unix group but NOT users (on-demand model)

**`app/models/course_user_datum.rb`**
- Calls `UnixGroupManager.update_course_staff_membership` on role changes
- Only adds to groups if user exists (users created on-demand)

### 3.4 Controllers

**`app/controllers/users_controller.rb`**
- `ssh_keys`: Shows SSH keys for a user (staff/admin only)
- `create_ssh_key`: Adds new SSH key (creates Unix user on-demand)
- `destroy_ssh_key`: Removes SSH key
- Authorization: Only staff/instructors or admins can manage keys

**`app/controllers/courses_controller.rb`**
- `create`: Creates Unix group on course creation
- `destroy`: Removes Unix group on course deletion
- `add_users_from_emails`: Updates group membership for staff
- `write_cuds`: Updates group membership when roster is uploaded

**`app/controllers/course_user_data_controller.rb`**
- `create`: Updates group membership when staff is added
- `update`: Updates group membership when role changes

### 3.5 Views

**`app/views/users/ssh_keys.html.erb`**
- Lists existing SSH keys
- Form to add new SSH key
- Shows Unix username and SSH command
- Only visible to staff/instructors

**`app/views/users/show.html.erb`**
- Link to "Manage SSH Keys" (for staff only)
- Shows Unix username if staff

### 3.6 Scripts

**`script/bootstrap_course_groups.rb`**
- Creates Unix groups for all existing courses
- Does NOT create users (users created on-demand)
- Fixes file permissions on course directories
- Supports `--dry-run` and `--course="name"` options

**`script/setup_host_system_user.sh`**
- Creates `autolab` system user on host
- Moves/mounts files to proper location
- Sets ownership to `autolab:autolab`

**`script/create_host_instructor_users.sh`**
- Syncs Unix users from container to host (for SSH access)
- Creates users on host with matching UIDs

**`script/test_ssh_unix.sh`**
- Automated testing script
- Tests migrations, system commands, user/group creation
- Verifies permissions and SSH setup

---

## 4. Docker Integration

### Configuration

Unix operations now run in a dedicated sidecar (`unixops`) so the main Rails container stays unprivileged. Example `docker-compose.yml` excerpt:

```yaml
services:
  autolab:
    environment:
      - UNIX_OPS_DELEGATE_URL=http://unixops:4000
      - UNIX_OPS_SHARED_SECRET=${UNIX_OPS_SHARED_SECRET?err}

  unixops:
    build: ./Autolab
    command: bundle exec ruby script/unix_ops_daemon.rb
    environment:
      - RAILS_ENV=production
      - UNIX_OPS_SHARED_SECRET=${UNIX_OPS_SHARED_SECRET?err}
    user: "0:0"
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
    volumes:
      - ./Autolab:/home/app/webapp                      # access to Rails codebase
      - /etc/passwd:/etc/passwd:rw                      # host user database
      - /etc/group:/etc/group:rw                        # host group database
      - /etc/shadow:/etc/shadow:rw                      # host password hashes
      - /etc/gshadow:/etc/gshadow:rw                    # host group shadow
      - /home:/home:rw                                  # host home directories
```

### How It Works

**Bind mounts on the `unixops` sidecar** expose real host inodes to the daemon:
- When the daemon runs `useradd`, it edits the host's `/etc/passwd`
- When it updates permissions with `File.chown`, the host inode changes immediately
- SSH keys written to `/home/<user>/.ssh/authorized_keys` live on the host
- The Rails container delegates work via `UNIX_OPS_DELEGATE_URL` → `unixops` handles it

Because bind mounts share inodes, changes survive container restarts and remain on the host.

### Verification

After setup, verify users/groups exist on **HOST**:

```bash
# On HOST (outside container)
id haoyuy              # Should work - user exists on host
getent group 15-122    # Should work - group exists on host
ls -la /home/haoyuy/   # Should show home directory on host

# Check helper health (inside docker network)
curl -sf http://unixops:4000/health
```

---

## 5. User Flow

### For Instructors

1. **Add staff to course** → No Unix user created yet
2. **Instructor adds SSH key via web UI** (`/users/<id>/ssh_keys`)
3. **Unix user created** (on-demand) + added to all course groups
4. **SSH key provisioned** to `authorized_keys`
5. **Instructor SSHs in** → Can access course directories via group membership

### For Administrators

1. **Create course** → Unix group created automatically
2. **Add staff** → Group membership tracked (no user created)
3. **Staff adds SSH key** → Unix user created + added to groups
4. **Delete course** → Unix group removed automatically

---

## 6. Security Features

✅ **SSH Key Only**: No password authentication (password locked with `*`)  
✅ **Authorization**: Only staff/instructors can manage SSH keys  
✅ **Group Isolation**: Instructors only access courses they're staff in  
✅ **File Permissions**: Enforced via Unix groups and setgid bit  
✅ **On-Demand Users**: No unused Unix accounts  
✅ **Cross-Platform Safe**: Gracefully handles macOS development  
✅ **Delegated Unix Ops**: Web container remains unprivileged; helper handles root actions

---

## 7. Testing

### Automated Test Script

`script/test_ssh_unix.sh`:
- Tests migrations
- Checks system commands availability
- Tests UnixGroupManager
- Lists courses and groups
- Tests SSH key creation
- Verifies file permissions

### Manual Verification

```bash
# Check user exists on host
id haoyuy

# Check group exists on host
getent group 15-122

# Check SSH key is provisioned
cat /home/haoyuy/.ssh/authorized_keys

# Test SSH login
ssh haoyuy@host-ip

# Check file permissions
ls -lad /home/autolab/Autolab/courses/15-122/
# Should show: drwxrws--- root:grp-15-122
```

---

## 8. Files Changed

### New Files
- `db/migrate/20251102150304_create_ssh_keys.rb`
- `app/models/ssh_key.rb`
- `app/services/unix_group_manager.rb`
- `app/services/filesystem_enforcer.rb`
- `app/views/users/ssh_keys.html.erb`
- `script/bootstrap_course_groups.rb`
- `script/setup_host_system_user.sh`
- `script/create_host_instructor_users.sh`
- `script/test_ssh_unix.sh`
- `script/unix_ops_daemon.rb`

### Modified Files
- `app/models/user.rb` (added `has_many :ssh_keys`, `staff?`, `course_assistant?`)
- `app/models/course.rb` (calls `setup_course_group`)
- `app/models/course_user_datum.rb` (calls `update_course_staff_membership`)
- `app/controllers/users_controller.rb` (SSH key management)
- `app/controllers/courses_controller.rb` (group management)
- `app/controllers/course_user_data_controller.rb` (group membership)
- `app/controllers/api/v1/course_user_data_controller.rb` (group membership)
- `app/views/users/show.html.erb` (SSH key link)
- `config/routes.rb` (SSH key routes)
- `config/application.rb` (added services to autoload paths)

---

## 9. Deployment Checklist

### Initial Setup

1. ✅ Create `autolab` system user on host
   ```bash
   useradd -r -m -s /bin/bash -d /home/autolab -c "Autolab System User" autolab
   ```

2. ✅ Clone repository and checkout feature branch
   ```bash
   cd /home/autolab
   git clone https://github.com/autolab/Autolab.git
   cd Autolab
   git checkout feature/filesystem-mapping
   chown -R autolab:autolab /home/autolab/Autolab
   ```

3. ✅ Enable Unix ops delegation in `docker-compose.yml`
   ```yaml
   services:
     autolab:
       environment:
         - UNIX_OPS_DELEGATE_URL=http://unixops:4000
         - UNIX_OPS_SHARED_SECRET=${UNIX_OPS_SHARED_SECRET?err}

     unixops:
       build: ./Autolab
       command: bundle exec ruby script/unix_ops_daemon.rb
       environment:
         - RAILS_ENV=production
         - UNIX_OPS_SHARED_SECRET=${UNIX_OPS_SHARED_SECRET?err}
       user: "0:0"
       cap_add:
         - CHOWN
         - DAC_OVERRIDE
         - FOWNER
         - SETGID
         - SETUID
       volumes:
         - ./Autolab:/home/app/webapp
         - /etc/passwd:/etc/passwd:rw
         - /etc/group:/etc/group:rw
         - /etc/shadow:/etc/shadow:rw
         - /etc/gshadow:/etc/gshadow:rw
         - /home:/home:rw
   ```

4. ✅ Run migrations
   ```bash
   docker exec autolab bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails db:migrate"
   ```

5. ✅ Run bootstrap script (creates Unix groups)
   ```bash
   docker exec -u root autolab bash -c "cd /home/app/webapp && RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb"
   ```

### Verification

```bash
# Verify users/groups on host (outside container)
id haoyuy                    # Should show user exists on host
getent group 15-122          # Should show group exists on host
ls -la /home/haoyuy/.ssh/    # Should show .ssh directory
cat /home/haoyuy/.ssh/authorized_keys  # Should show SSH keys

# Verify file permissions
ls -lad /home/autolab/Autolab/courses/15-122/
# Should show: drwxrws--- root:grp-15-122
```

---

## 10. Key Achievements

✅ **Per-course Unix groups** for access control  
✅ **On-demand Unix user creation** (only when SSH key added)  
✅ **SSH key management** via web UI  
✅ **Automatic file permission enforcement**  
✅ **Group-based file isolation** (instructors only see their courses)  
✅ **Docker integration** that creates users/groups on host  
✅ **Bind mount permissions persist** (changes survive container restarts)  
✅ **Cross-platform safe** (gracefully handles macOS development)

---

## 11. Technical Highlights

### On-Demand User Creation

**Old Model**: Staff added → Unix user created immediately  
**New Model**: Staff added → No user created  
**New Model**: SSH key added → Unix user created + added to all course groups

**Benefits**:
- No unused Unix accounts
- Users only exist when they need SSH access
- Cleaner system state
- Better security

### Bind Mount Integration

**Key Insight**: Bind mounts share the same inodes between host and container.

- Container operations affect host filesystem
- Permission changes persist on host
- No special handling needed - it just works!

### File Permission Model

- **Course directories**: `drwxrws---` (2770) with setgid bit
- **Course files**: `-rw-rw----` (660)
- **Group-based access**: Instructors access via group membership
- **Automatic enforcement**: Permissions fixed on file uploads

---

## 12. Next Steps

1. **Deploy to production** with proper Docker configuration
2. **Migrate existing courses** using bootstrap script
3. **Instructors add SSH keys** via web UI
4. **Verify file isolation** (instructors only see their courses)
5. **Monitor and optimize** as needed

---

## 13. Conclusion

We've successfully implemented a complete, production-ready file system permission and SSH key management system for Autolab. The system provides:

- ✅ Secure, isolated file access via Unix groups
- ✅ On-demand Unix user creation (only when needed)
- ✅ SSH key authentication (no passwords)
- ✅ Docker integration (works with host filesystem)
- ✅ Automatic permission enforcement
- ✅ Web UI for SSH key management

The implementation is complete and ready for deployment.

---

**Branch**: `feature/filesystem-mapping`  
**Commit**: Latest changes pushed to GitHub  
**Status**: ✅ Ready for Review

