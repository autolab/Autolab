# Permission Model

This page documents Autolab’s filesystem permission model, Unix identity management, and SSH access flow.

---

## Objectives

- Enforce per-course Unix group isolation.
- Provision instructor Unix users on demand.
- Ensure uploaded/autograder files inherit secure permissions.
- Enable SSH access using public keys.
- Delegate privileged host operations from Rails safely.

---

## Architecture

1. **Per-course Unix groups**
   - A course group is ensured when a course is created.
   - Directory ownership/mode is enforced so staff access is group-scoped.

2. **Delegated privileged operations**
   - The web app delegates privileged Unix tasks (e.g., `useradd`, `groupadd`, `chown`) to a dedicated helper process/container.
   - Delegation is controlled with `UNIX_OPS_DELEGATE_URL` and `UNIX_OPS_SHARED_SECRET`.

3. **Filesystem enforcement**
   - Course trees are normalized to secure ownership/modes.
   - New files/directories inherit group permissions via setgid behavior.

4. **Graceful non-prod behavior**
   - In environments where Unix ops are unavailable, provisioning operations are skipped.

---

## Key Components

- `UnixGroupManager`: service for delegated/local Unix operations.
- `FilesystemEnforcer`: enforces ownership and mode policy.
- `SshKey`: validates and stores public keys; triggers provisioning.
- `UsersController`: SSH key actions: user-facing key management.

---

## Permission Model Alignment

This implementation is aligned with the Autolab authorization model in [security-model.md](security-model.md):

- **Administrators**
  - Global authority in app authorization.
  - Can manage instructor SSH keys and provisioning.

- **Instructors**
  - Can manage their own SSH keys.
  - Added to course Unix groups for course filesystem access.

- **Course assistants / students**
  - Not provisioned for host filesystem SSH access by default.
  - Not added to instructor-grade Unix filesystem access paths unless explicitly configured.

### Filesystem policy

- Course directories are expected to be `drwxrws---` (`2770`) with course-group ownership.
- Files are expected to be group-readable/writable and not world-readable.
- Group inheritance is preserved with setgid directory bits.

---

## SSH Key Lifecycle

1. Instructor/admin submits a public key in the UI.
2. Key is validated and stored.
3. Provisioning ensures Unix account and home/`.ssh` structure.
4. Active keys are synchronized to `authorized_keys`.
5. On key deletion, remaining keys are re-synced.

---

## Required configuration

- `UNIX_OPS_DELEGATE_URL`
- `UNIX_OPS_SHARED_SECRET`
- optional: `UNIX_OPS_DELEGATE_TIMEOUT`
- optional: `AUTOLAB_HOST_COURSES_ROOT` (default: `/home/autolab/docker/Autolab/courses`)

---

## Scripts to run

Run these in order.

1. **Bootstrap course Unix groups and permissions**
   - `sudo chmod o+x /home/ubuntu`  # Ensure parent directory is traversable for group members
   - `docker compose exec autolab bundle exec rails runner -e production script/bootstrap_course_groups.rb`

2. **Run verification harness**
   - `./script/test_ssh_unix.sh autolab`

3. **(Optional) One-time host preparation**
   - Run only when host-level Unix users/ownership are not set up yet:
   - `sudo ./script/setup_host_system_user.sh`

4. **(Optional) Host user sync (legacy/non-delegate setups)**
   - If instructors must SSH directly to host accounts managed outside the delegate flow:
   - `sudo ./script/create_host_instructor_users.sh autolab`

---

## Verification Checklist

- Delegate health endpoint reachable from web app.
- Course group exists and instructor membership is correct.
- User home and `authorized_keys` are created with secure ownership.
- Course directory modes are locked down and setgid is preserved.

---

## Troubleshooting

- **`cd <course>` returns `No such file or directory` from `~/courses`**
   - This usually means the per-user course link points to the wrong host path.
   - Verify the link target:
      - `readlink -f ~/courses/<course-name>`
   - Ensure `AUTOLAB_HOST_COURSES_ROOT` matches your host checkout path (for example, `/home/ubuntu/autolab-docker/Autolab/courses` on some deployments).
   - Recreate user links by re-syncing SSH keys/provisioning (or trigger `ensure_courses_directory` via key update flow).

- **Bootstrap prints `chgrp: invalid group` inside the Rails container**
   - In delegate mode, groups are host-scoped and may not exist in the container's group database.
   - This is handled by delegate-backed permission enforcement; use the updated bootstrap script that applies delegated filesystem enforcement.
