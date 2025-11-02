# Autolab Filesystem Design

## Recommended Structure

### Directory Layout

```
/opt/autolab/                          # Main application (owned by autolab:autolab)
├── app/                               # Rails application code
├── config/                            # Configuration files
├── log/                               # Application logs
└── tmp/                               # Temporary files

/srv/autolab/                          # Service data (owned by root:autolab-staff)
├── courses/                           # Course directories (group ownership)
│   ├── 15-122/                        # drwxrws--- root:grp-15-122
│   └── Test/                          # drwxrws--- root:grp-Test
├── courseConfig/                      # Course configuration
├── assessmentConfig/                  # Assessment configuration
├── storage/                           # Active Storage files
└── data/                              # Other persistent data

/var/lib/autolab/                      # Variable data (owned by autolab:autolab)
├── db/                                # Database files (if SQLite)
└── cache/                             # Cache files

/var/log/autolab/                      # Application logs (owned by autolab:autolab)
└── production.log

/etc/autolab/                          # Configuration files (owned by root:root)
├── database.yml
├── production.rb
└── smtp_config.yml
```

## Ownership Model

### System Users

```bash
# System user for Autolab (no login, no home directory)
useradd -r -s /bin/false -d /opt/autolab -c "Autolab Application User" autolab

# Service group for Autolab administrators/staff
groupadd autolab-staff
```

### File Ownership

1. **Application Files** (`/opt/autolab/`):
   - Owner: `autolab:autolab`
   - Permissions: `755` for directories, `644` for files
   - Purpose: Rails application code, static files

2. **Course Data** (`/srv/autolab/courses/`):
   - Owner: `root:<course-group>` (e.g., `root:grp-15-122`)
   - Permissions: `2770` for directories, `660` for files (setgid + group rw)
   - Purpose: Course files, isolated by group

3. **Configuration** (`/etc/autolab/`):
   - Owner: `root:root`
   - Permissions: `640` (readable by root and autolab group)
   - Purpose: Sensitive configuration files

4. **Instructor Home Directories** (`/home/<username>/`):
   - Owner: `<username>:<username>`
   - Permissions: `700` for home, `600` for `.ssh/authorized_keys`
   - Purpose: SSH access, user-specific files

## Docker Volume Mapping

### Recommended docker-compose.yml volumes:

```yaml
services:
  autolab:
    volumes:
      # Application code (read-only for security)
      - /opt/autolab/app:/home/app/webapp:ro
      
      # Course data (read-write, group-protected)
      - /srv/autolab/courses:/home/app/webapp/courses
      - /srv/autolab/courseConfig:/home/app/webapp/courseConfig
      - /srv/autolab/assessmentConfig:/home/app/webapp/assessmentConfig
      - /srv/autolab/storage:/home/app/webapp/storage
      
      # Configuration (read-only)
      - /etc/autolab/database.yml:/home/app/webapp/config/database.yml:ro
      - /etc/autolab/production.rb:/home/app/webapp/config/environments/production.rb:ro
      
      # Logs
      - /var/log/autolab:/home/app/webapp/log
      
      # Database (if local)
      - /var/lib/autolab/db:/home/app/webapp/db
```

## Migration Path

### Step 1: Create Structure

```bash
# Create system user
useradd -r -s /bin/false -d /opt/autolab autolab

# Create directories
mkdir -p /opt/autolab/{app,log,tmp}
mkdir -p /srv/autolab/{courses,courseConfig,assessmentConfig,storage,data}
mkdir -p /var/lib/autolab/db
mkdir -p /var/log/autolab
mkdir -p /etc/autolab

# Set ownership
chown -R autolab:autolab /opt/autolab
chown -R root:root /srv/autolab/courses  # Will be changed per-course
chown -R autolab:autolab /var/lib/autolab
chown -R autolab:autolab /var/log/autolab
chown root:root /etc/autolab

# Set permissions
chmod 755 /opt/autolab
chmod 755 /srv/autolab
chmod 750 /etc/autolab
```

### Step 2: Move Existing Data

```bash
# Move from current location
mv /home/user9999/autolab-docker/Autolab/* /opt/autolab/app/
mv /home/user9999/autolab-docker/Autolab/courses/* /srv/autolab/courses/
mv /home/user9999/autolab-docker/Autolab/courseConfig/* /srv/autolab/courseConfig/
mv /home/user9999/autolab-docker/Autolab/assessmentConfig/* /srv/autolab/assessmentConfig/
mv /home/user9999/autolab-docker/Autolab/storage/* /srv/autolab/storage/
mv /home/user9999/autolab-docker/Autolab/config/* /etc/autolab/

# Update ownership
chown -R autolab:autolab /opt/autolab
chown -R root:root /srv/autolab/courses

# Apply course group permissions (via bootstrap script)
cd /opt/autolab/app
RAILS_ENV=production bundle exec rails runner script/bootstrap_course_groups.rb
```

### Step 3: Update Docker Compose

Update `docker-compose.yml` with new volume paths.

## Alternative: Simpler Approach (Current Migration)

If you want to keep things simpler for now:

```
/home/autolab/                         # Application home
├── webapp/                            # Rails app
└── data/                              # Mounted volumes
    ├── courses/                       # Course directories
    ├── courseConfig/
    ├── assessmentConfig/
    └── storage/
```

**Benefits:**
- Easier migration (less moving files)
- Still separate from random user9999
- Can migrate to `/opt`/`/srv` later

## Security Model

### Group-Based Access Control

1. **Course Groups**: `grp-<course-name>` (e.g., `grp-15-122`)
   - Instructors/TAs are members
   - Course directories owned by `root:grp-<course-name>`
   - Permissions: `2770` (setgid, group rw)

2. **Application Group**: `autolab`
   - Rails application runs as `app:app` in container
   - Application files owned by `autolab:autolab` on host

3. **Staff Group**: `autolab-staff` (optional)
   - For administrators who need broader access
   - Can access `/srv/autolab/` parent directories

## Backup Strategy

With this structure:

```bash
# Application code (rarely changes)
tar czf autolab-app-$(date +%Y%m%d).tar.gz /opt/autolab/

# Course data (changes frequently)
tar czf autolab-courses-$(date +%Y%m%d).tar.gz /srv/autolab/courses/

# Configuration
tar czf autolab-config-$(date +%Y%m%d).tar.gz /etc/autolab/
```

## Recommended: Minimal Change Approach

For your current situation, minimal change:

1. **Create system user**:
   ```bash
   useradd -r -m -s /bin/bash -d /home/autolab autolab
   ```

2. **Move files to `/home/autolab/`**:
   ```bash
   mv /home/user9999/autolab-docker /home/autolab/docker
   chown -R autolab:autolab /home/autolab
   ```

3. **Keep structure but better owner**:
   - `/home/autolab/docker/Autolab/` → owned by `autolab:autolab`
   - Course directories → owned by `root:<course-group>` (via bootstrap)

This is simpler than full `/opt`/`/srv` migration but still better than `user9999`.

