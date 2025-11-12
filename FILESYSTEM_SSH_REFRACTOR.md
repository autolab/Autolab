# Autolab Filesystem & SSH Refactor Guide

This document summarizes the full journey of refactoring Autolab’s filesystem permissions, Unix identity management, and SSH access. Follow it to understand the architecture, reproduce the deployment, or onboard new operators.

---

## 1. Objectives & Legacy State

**Goal**

- Create per-course Unix groups with correct directory permissions.
- Give instructors/TAs individual Unix accounts, provisioned only when they add SSH keys.
- Ensure file uploads/autograde output inherit setgid permissions.
- Enable SSH access using keys, not passwords.
- Make the Dockerized Rails app modify the host’s filesystem and user database reliably.

**Legacy issues**

- All course files were group/world readable (`drwxrwxr-x`).
- No course-level isolation; any instructor could inspect others’ directories.
- Only one Unix user for the app; no per-user credentials or SSH access.
- No Rails ↔ Unix integration; manual fixes were brittle.

---

## 2. Architecture Overview

1. **On-demand Unix accounts**
   - Course group (e.g. `grp-15-122`) is ensured when the course is created.
   - Staff Unix accounts are created only when they add their first SSH key in the UI.

2. **Delegated Unix operations**
   - A dedicated helper container (`unixops`) performs privileged operations (`useradd`, `groupadd`, etc.).
   - The web container (`autolab`) posts JSON jobs to the helper via `UNIX_OPS_DELEGATE_URL` and a shared secret.

3. **Filesystem enforcement**
   - `FilesystemEnforcer.fix_tree` keeps course directories at `drwxrws---` and files at `rw-rw----`.
   - Hooked into uploads, autograde, and bootstrap scripts.

4. **Graceful dev/CI experience**
   - On macOS or without `ENABLE_UNIX_OPS`, provisioning skips but still stores DB state.
   - Exceptions are logged, not fatal, so development continues smoothly.

---

## 3. Key Components

| Component | Purpose |
|-----------|---------|
| `app/services/unix_group_manager.rb` | Handles user/group creation, SSH key provisioning; delegates to helper if configured. |
| `app/services/filesystem_enforcer.rb` | Applies ownership/mode to course directories and files. |
| `app/models/ssh_key.rb` | Validates keys, persists metadata, and triggers provisioning. |
| `script/unix_ops_daemon.rb` | WEBrick daemon that executes privileged Unix operations. |
| `script/test_ssh_unix.sh` | CLI test harness to verify delegation, permissions, and key provisioning. |
| `script/bootstrap_course_groups.rb` | Idempotent script to create course groups, fix permissions. |
| SSH key views/controllers | UI for instructors to manage their keys with proper authorization. |

---

## 4. Docker Deployment

### 4.1 Services

```yaml
services:
  autolab:
    build: ./Autolab
    depends_on: [mysql, certbot]
    ports: ['80:80', '443:443']
    environment:
      - UNIX_OPS_DELEGATE_URL=http://unixops:4000
      - UNIX_OPS_SHARED_SECRET=${UNIX_OPS_SHARED_SECRET?err}
      - HOST_COURSES_PATH=/home/autolab/autolab-docker/Autolab/courses
      # ... existing env vars ...
    volumes:
      # Specific sub-directory mounts (database.yml, courses/, etc.) as before
      - ./ssl/certbot/conf:/etc/letsencrypt
      - ./ssl/certbot/www:/var/www/certbot
      - ./nginx/no-ssl-app.conf:/etc/nginx/sites-enabled/webapp.conf

  unixops:
    container_name: unixops
    build: ./Autolab
    command: bundle exec ruby script/unix_ops_daemon.rb -p 4000
    environment:
      - RAILS_ENV=production
      - UNIX_OPS_SHARED_SECRET=${UNIX_OPS_SHARED_SECRET?err}
      - HOST_COURSES_PATH=/home/autolab/autolab-docker/Autolab/courses
    user: "0:0"
    privileged: true
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
      - FSETID
      - DAC_READ_SEARCH
    volumes:
      - ./Autolab:/home/app/webapp
      - /etc:/etc:rw
      - /home:/home:rw
      - /var:/var:rw        # optional but useful for lock files
```

**Why mount entire `/etc`?**  
Tools like `groupadd` create lock files (`/etc/group.lock`). Without write access to the directory, they fail with “failure while writing changes to /etc/group.”

**Security notes**
- Keep the helper on an internal network; expose only to the web container.
- Shared secret should be injected via environment (e.g., Compose `.env` file).
- Consider additional network policies or service mesh ACLs in production.

### 4.2 Lifecycle

```bash
docker compose down
docker compose build --no-cache autolab unixops
docker compose up -d autolab unixops
docker compose exec autolab bundle exec rails db:migrate RAILS_ENV=production
docker compose exec autolab bundle exec rails runner -e production script/bootstrap_course_groups.rb
```

---

## 5. End-to-End Flow

1. **Course creation**
   - Rails ensures Unix group (delegated if helper available).
   - Permission bootstrap sets setgid bits on course directories.

2. **Instructor adds SSH key via UI**
   - Key validated and stored in DB.
   - `SshKey#after_save` calls `UnixGroupManager.provision_key`.
   - Helper is invoked to `ensure_user`, `setup_user_home`, `provision_ssh_key`, and update group memberships.

3. **Host state after provisioning**
   - `/home/<username>/.ssh/authorized_keys` exists and is owned by `username:username`.
   - `getent group <course>` lists instructor membership.
   - `id <username>` shows group membership; instructor navigates to `/home/autolab/.../courses/<course>` to work.

4. **Key removal**
   - Key deleted from DB; helper removes it from host.
   - Remaining active keys are re-provisioned to keep `authorized_keys` accurate.

---

## 6. Testing & Verification

### Automated harness
```bash
./script/test_ssh_unix.sh autolab
```
Reports delegate status, course permissions, and sample provisioning outcome.

### Manual checklist
```bash
# Check delegate connectivity
docker compose exec autolab env | grep UNIX_OPS
docker compose exec autolab curl -sf http://unixops:4000/health
docker compose exec autolab bash -lc \
  'cd /home/app/webapp && DISABLE_SPRING=1 bundle exec rails runner -e production "puts UnixGroupManager.delegate_enabled?"'

# After uploading a key
getent group 15-122
id haoyuy
cat /home/haoyuy/.ssh/authorized_keys
ls -lad /home/haoyuy/courses
ls -lad /home/haoyuy/courses/15-122
ssh haoyuy@<host-ip>
```

### Troubleshooting tips
- Always disable Spring for one-off `rails runner` commands:
  ```bash
  DISABLE_SPRING=1 bundle exec rails runner -e production '...'
  ```
- Tail helper log during provisioning:
  ```bash
  docker compose exec unixops bash -lc 'cd /home/app/webapp && tail -f log/production.log'
  ```
- If helper logs “failure while writing changes to /etc/group,” check `/etc` mount and privileges.

---

## 7. Deployment Checklist

1. **Host preparation**
   - Create `autolab` system user.
   - Clone repository under `/home/autolab`.
   - Ensure directory permissions allow other users to traverse (`chmod 755 /home/autolab` etc.).

2. **Docker setup**
   - Configure `docker-compose.yml` with:
     - `unixops` service and required mounts.
     - `UNIX_OPS_SHARED_SECRET` for both containers.
   - Remove `version: "3.3"` to avoid Compose warnings.

3. **Build & run**
   - `docker compose build --no-cache autolab unixops`
   - `docker compose up -d`
   - Run migrations and bootstrap script.

4. **Sanity testing**
   - `./script/test_ssh_unix.sh autolab`
   - Add SSH key via UI → check helper logs & host filesystem.
   - SSH into host as instructor.

5. **Monitoring & maintenance**
   - Monitor helper logs for provisioning errors.
   - Optionally expose a health endpoint (`/health`) to your monitoring stack.

---

## 8. Known Behaviors & Notes

- **Instructor landing directory**: Instructors log in to their home (`/home/<user>`). A symlink `~/courses → /home/autolab/autolab-docker/Autolab/courses` is created automatically, so `cd ~/courses/<course>` takes them straight to their course materials.
- **Development mode**: Without `ENABLE_UNIX_OPS`, provisioning is skipped; logs warn but key still persists in DB.
- **MacOS / non-Linux dev**: operations short-circuit gracefully.
- **Security**: The helper runs privileged—limit access to trusted networks, and log/audit operations.

---

## 9. Handy Commands

```bash
# Re-provision all active keys for a user
docker compose exec autolab bash -lc '
  cd /home/app/webapp &&
  DISABLE_SPRING=1 bundle exec rails runner -e production "
    email = \"user@example.com\"
    user = User.find_by(email: email)
    username = UnixGroupManager.login_from_email(email)
    keys = user.ssh_keys.where(active: true).pluck(:public_key)
    UnixGroupManager.setup_user_home(username)
    UnixGroupManager.provision_ssh_keys(username, keys, email: email)
  "
'

# Tail helper log
docker compose exec unixops bash -lc 'cd /home/app/webapp && tail -f log/production.log'
```

---

## 10. Status & Deliverables

- **Code**: All changes merged into `feature/filesystem-mapping`.
- **Documentation**: This guide plus `MEETING_REPORT.md`.
- **Testing**: UI and manual provisioning verified; SSH login successful.
- **Open items**: None. Optional enhancements include bulk re-provision scripts and additional monitoring.

---

## 11. FAQ

**Why mount whole `/etc` in the helper?**  
Because `groupadd`/`usermod` creates temporary lock files beside the target; binding only individual files blocks these operations.

**Can we avoid rebuilding on change?**  
Either mount the folders that hold changing code (e.g. `./Autolab/app/services`) or rebuild with `--no-cache`. We used partial mounts + rebuild in production setups.

**What about staff who already had Unix accounts?**  
Run `script/create_host_instructor_users.sh` once to sync existing staff, or rely on the delegate after they add keys.

---

Everything is now tested end-to-end: adding keys via UI provisions Unix users, assigns course groups, and keeps `authorized_keys` up-to-date on the host. SSH access behaves exactly like the legacy AFS model but in a Docker-friendly environment.

