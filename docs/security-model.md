# Autolab Security Model

This document describes the authorization and permission model used throughout Autolab, covering roles, resource ownership, and access control across the application.

---

## Overview

Autolab uses a **role-based, per-course authorization system**. Permissions are not global; a user's role is defined separately for each course they belong to via a `CourseUserDatum` (CUD) join record. The one exception is the **Administrator** role, which is a global flag on the `User` model.

Authorization is enforced in `ApplicationController` via the `action_auth_level` class macro and the `authenticate_for_action` before-action callback. Every controller action that requires authentication declares a minimum required auth level, and the framework validates it before the action runs.

---

## Auth Level Hierarchy

Auth levels are ordered, and each level implicitly includes all permissions of the levels below it:

```
administrator > instructor > course_assistant > student
```

Defined in `CourseUserDatum::AUTH_LEVELS`:

```ruby
AUTH_LEVELS = %i[student course_assistant instructor administrator].freeze
```

The `has_auth_level?` method encodes the hierarchy:

| Requested Level   | Granted If…                                              |
|-------------------|----------------------------------------------------------|
| `:student`        | Always (any enrolled user)                               |
| `:course_assistant` | `course_assistant?` OR `instructor?` OR `administrator?` |
| `:instructor`     | `instructor?` OR `administrator?`                        |
| `:administrator`  | `administrator?` (global flag on `User`)                 |

---

## Roles

### Student

- Default role for any user enrolled in a course.
- A user is a student when they have a CUD for the course but neither the `instructor` nor `course_assistant` flag is set (`student?` returns `true` iff `!(instructor? || course_assistant?)`).
- Students can only see their **own** work: submissions, scores, and feedback.
- Students cannot see unreleased assessments. The `set_assessment` before-action redirects them away if `!@assessment.released?`.
- A **dropped** student (`dropped: true`) cannot submit or download assessments, and does not appear in gradebooks. Their account data and submissions are preserved.
- Students can create and manage submission **groups** (join, leave, add members), but cannot delete groups.

### Course Assistant (CA)

- Assigned by setting the `course_assistant` flag on a CUD.
- CAs are **section-scoped**: `CA_of?(student)` is `true` only when both share the same `section` and `lecture`.
- CAs can enter/modify scores and annotations for submissions they supervise.
- CAs can **release section grades** — notably, instructors cannot do this directly (`CA_only?` enables this distinction).
- Cannot drop students, manage users, or perform course-level administrative actions.
- Instructors and CAs **cannot** be in a `dropped` state (validated by `instructor_or_ca_not_dropped`).

### Instructor

- Assigned by setting the `instructor` flag on a CUD.
- Has **full read/write access** to all course data within their course.
- Can manage course settings, users, rosters, assessments, submissions, extensions, and schedulers.
- Can **sudo** (impersonate) any non-administrator user within their course via `CourseUserDataController#sudo`. An instructor cannot sudo to an administrator.
- Cannot create or delete **courses** — that is reserved for administrators.
- Cannot **delete users** from the system — only administrators can do that.

### Administrator

- A **global** flag (`administrator` boolean) on the `User` model, not course-scoped.
- Administrators can access any course and are **automatically enrolled** as instructor-level CUDs whenever they visit a course they are not yet a member of.
- Only administrators can create courses, create courses from tarballs, and destroy courses.
- Only administrators can delete user accounts from the system.
- Administrators can email all instructors, manage GitHub integration, clear caches, and modify Autolab system configuration.
- Administrators bypass all course-level access checks — `find_or_create_cud_for_course` creates an admin CUD on-the-fly with `instructor: true, course_assistant: true`.

---

## Resource Ownership

### Courses

| Concern                | Details                                                                                   |
|------------------------|-------------------------------------------------------------------------------------------|
| **Who creates courses** | Only `administrator`-level users. (`CoursesController#new` and `#create` are `:administrator`.) |
| **Who destroys courses** | Only `administrator`-level users. (`CoursesController#destroy` is `:administrator`.)       |
| **Course "owner"**      | When a course is created, an email address is supplied and a `CourseUserDatum` with `instructor: true` is created for that user. There is no exclusive single-owner concept beyond being the first instructor. |
| **Default group instructor** | Autolab ensures a designated service user (configurable via `AUTOLAB_DEFAULT_GROUP_INSTRUCTOR`) is enrolled as an instructor to facilitate filesystem access for the course Unix group. |
| **Disabled courses**    | Instructors can disable a course. Disabled courses are inaccessible to students and CAs; only instructors can still access them. |
| **Editing/managing**    | Any instructor in the course can edit course settings, manage users, upload rosters, and reload config. |

### Assessments

| Concern                 | Details                                                                                                  |
|-------------------------|----------------------------------------------------------------------------------------------------------|
| **Association**         | An `Assessment` `belongs_to :course` and `belongs_to :course_user_datum` (the creating instructor's CUD). |
| **Who can create**      | Instructors only (`:instructor`): `new`, `install_assessment`, `import_asmt_from_tar`, `create`.         |
| **Who can edit/delete** | Instructors only (`:instructor`): `edit`, `update`, `destroy`, `reload`, `releaseAllGrades`, `withdrawAllGrades`, `regrade`, `regradeAll`, `export`. |
| **Visibility to students** | An assessment is visible to students only after its `start_at` time has passed (`released?`). Unreleased assessments are hidden from students entirely. |
| **Student actions**     | Students can: `show` (if released), `handin`, `handout`, `history`, `viewFeedback`, `getPartialFeedback`, `writeup`. |
| **CA actions**          | CAs can: `bulkGrade`, `quickSetScore`, `quickSetScoreDetails`, `viewGradesheet`, `quickGetTotal`, `releaseSectionGrades`, `excuse_popover`, `score_grader_info`, `submission_popover`. |
| **Statistics**          | Assessment statistics are instructor-only. |

### Submissions

| Concern                 | Details                                                                                                  |
|-------------------------|----------------------------------------------------------------------------------------------------------|
| **Association**         | A `Submission` `belongs_to :course_user_datum` (the submitting student's CUD) and `belongs_to :assessment`. It also tracks `submitted_by` (a CUD), which may differ when an instructor creates a submission on behalf of a student. |
| **Who can create**      | Students submit via `handin`. Instructors can also create submissions manually (`:instructor`: `new`, `create`). |
| **Who can view**        | Students can only download/view **their own** submissions. Instructors and CAs bypass this check (`set_submission` enforces `@submission.course_user_datum_id == @cud.id` for students). Exam submissions are additionally blocked from student view during an active exam. |
| **Who can edit/delete** | Only instructors (`:instructor`): `edit`, `update`, `destroy`, `destroy_batch`. |
| **Downloading all**     | CAs and above: `download_all`, `download_batch`. |
| **Releasing grades**    | CAs can release and unrelease individual student grades (`release_student_grade`, `unrelease_student_grade`). Instructors can bulk-release all grades (`releaseAllGrades`, `withdrawAllGrades`). |
| **Excusing**            | CAs can excuse/unexcuse submissions (`excuse_batch`, `unexcuse`). |

### Scores and Annotations

| Concern             | Details                                                                           |
|---------------------|-----------------------------------------------------------------------------------|
| **Scores**          | CAs and above can create, view, and update scores (`ScoresController`: `:course_assistant`). |
| **Annotations**     | CAs and above can create, update, and destroy annotations. Students are implicitly allowed to *read* annotations on their own submissions (via `viewFeedback`). |
| **Shared comments** | CAs can retrieve a list of shared annotation comments within an assessment. |

### Extensions

- Only **instructors** can create, view, and destroy deadline extensions for students.

### Attachments

- Instructors manage attachments (create, edit, delete).
- Students can view/download **released** attachments only. Instructors see all attachments including unreleased.

### Gradebooks

| Action          | Min Level         |
|-----------------|-------------------|
| `show`          | `:student`        |
| `student`       | `:student`        |
| `view`          | `:course_assistant` |
| `csv`           | `:instructor`     |
| `invalidate`    | `:instructor`     |
| `statistics`    | `:instructor`     |
| `bulk_release`  | `:instructor`     |

### Groups

- Students can create, join, leave, and manage groups.
- Only **instructors** can destroy groups or bulk-import group assignments.

### Schedulers

- All scheduler actions (create, read, update, delete, run) are **instructor-only**.

### Announcements

- System-level announcements are managed by administrators. Course-level announcements are managed by instructors.

---

## User Management

| Action                        | Min Level       | Notes                                                                      |
|-------------------------------|-----------------|----------------------------------------------------------------------------|
| List users (index)            | `:student`      | Students see only themselves; instructors see users in their courses; admins see all. |
| View user profile             | `:student`      | Students can only view their own profile. Instructors see users in their courses. |
| Create new user               | `:instructor`   | Instructors can create accounts within the context of a course.            |
| Edit own profile              | `:student`      | Any user can edit their own profile.                                       |
| Delete user                   | `:administrator`| Only administrators can permanently delete user accounts.                  |
| Manage course roster          | `:instructor`   | Upload/download CSV rosters.                                               |
| Add users from emails         | `:instructor`   | Bulk-add users with a specified role.                                      |
| Sudo (impersonate) a user     | `:instructor`   | Instructors can impersonate non-admin users within their own course. Admins can impersonate anyone. |
| Unsudo                        | `:student`      | Any user can end a sudo session.                                           |

---

## API Security (OAuth2)

The REST API (`/api/v1/...`) uses **OAuth2 via Doorkeeper**. All API requests must carry a valid bearer token. The API defines the following scopes:

| Scope            | Description                                                    |
|------------------|----------------------------------------------------------------|
| `user_courses`   | Read access to the user's courses and assessments.             |
| `user_scores`    | Read access to the user's submissions, scores, and feedback.   |
| `user_submit`    | Submit assessments on the user's behalf.                       |
| `instructor_all` | Full instructor-level access to courses where the user is an instructor. |
| `admin_all`      | Full administrator-level access.                               |

The `require_privilege` helper in `BaseApiController` checks both that:
1. The OAuth token carries the required scope, **and**
2. The authenticated user has the corresponding role in the course (e.g., `@cud.instructor` for `instructor_all`).

---

## Sudo / Impersonation

Instructors (and administrators) can "sudo" into another user's session within a course:

- The sudo session is stored in `session[:sudo]` with `user_id` and `course_id`.
- Sudo does **not** cross course boundaries: if the sudoing user navigates to a different course, the sudo is automatically cleared.
- `can_sudo_to?(cud)` logic:
  - Administrators can sudo to anyone.
  - Instructors can sudo to any non-administrator user in their own course.
- A user cannot sudo to themselves.

---

## Filesystem Security

Course directories on disk are owned by the Rails service user (`app`) and belong to a Unix group named after the course (e.g., `course-15213`). The permissions are `2770` (`drwxrws---`), meaning:

- Only the `app` service user (owner) and members of the course Unix group can read/write course files.
- The setgid bit ensures new files inherit the group.
- `FilesystemEnforcer.fix_tree` enforces this layout whenever instructor membership changes.
- Only **instructors** are added to the course Unix group (course assistants are not). Students are **not** added to the course group.

---

## Filesystem Permission Details

Autolab's filesystem is divided into several distinct areas, each with its own ownership and permission policy enforced by `FilesystemEnforcer` and `UnixGroupManager`.

### Directory Layout (in container)
```
<autolab-root>/
├── courses/                    # Per-course runtime data (submissions, logs, configs)
│   │                           # app:user9999  drwxr-xr-x (755) — parent container
│   └── <course-name>/          # app:<course-group>  drwxrws--- (2770)
│       ├── course.rb           # app:<course-group>  -rw-rw---- (660)
│       ├── autolab.log         # app:<course-group>  -rw-rw---- (660)
│       └── <handin-dirs>/      # app:<course-group>  drwxrws--- (2770)
│           └── <files>         # app:<course-group>  -rw-rw---- (660)
├── courseConfig/               # Shared course config copies (YAML/Ruby)
│   └── *.rb / *.yml            # app:autolab  drwxrwxr-x (775) on dir, no enforced file mode
├── assessmentConfig/           # Shared assessment config copies
│   └── *.rb / *.yml            # app:autolab  drwxrwxr-x (775) on dir
└── <other rails dirs>/         # app:user9999  drwxr-xr-x (755); not touched by FilesystemEnforcer
```

### Permission Constants

Defined in `FilesystemEnforcer`:

| Constant      | Octal  | Symbolic       | Applied to          |
|---------------|--------|----------------|---------------------|
| `MODE_DIR`    | `2770` | `drwxrws---`   | All directories under `courses/` |
| `MODE_FILE`   | `660`  | `-rw-rw----`   | All regular files under `courses/` |

The **setgid bit** (`2` in `2770`) ensures that new files and subdirectories created inside a course directory automatically inherit the course Unix group, even if the creating process's primary group differs.

### Per-Location Breakdown

#### `courses/<course-name>/` — Course Root Directory

| Property    | Value                                         |
|-------------|-----------------------------------------------|
| Owner       | Rails service user (`app`)                    |
| Group       | `<course-group>` (e.g., the course name, normalized to 32 chars, alphanumeric/hyphens/dots only) |
| Mode        | `2770` (`drwxrws---`)                         |
| Who can access | Only the `app` service user and members of the course Unix group (**instructors only**) |

This is the **terminal security boundary** for course data. The directory is locked down by `FilesystemEnforcer.fix_tree` after the course configuration is first loaded. It is re-locked whenever a staff member's CUD changes (instructor/CA added or removed, or dropped status changes).

**Temporary state during course creation:** While a new course is being initialized, the directory is owned by the `app` Rails process with mode `0775` so that `reload_course_config` can read `course.rb`. `FilesystemEnforcer.fix_tree` is called by the controller immediately after the config load succeeds, switching the directory to `app:<course-group> 2770`.

#### `courses/<course-name>/<files>` — Files Inside a Course Directory

| Property    | Value                                         |
|-------------|-----------------------------------------------|
| Owner (dirs)  | Rails service user (`app`)                  |
| Owner (files) | Rails service user (`app`)                  |
| Group       | `<course-group>`                              |
| Mode (dirs) | `2770`                                        |
| Mode (files)| `660` (`-rw-rw----`)                          |

Files include `course.rb`, `autolab.log`, and all student handin files. The `660` mode means only the file owner (Rails) and group members (staff) can read or write them — world access is denied entirely.

#### `courseConfig/` and `assessmentConfig/` — Shared Config Directories

These directories hold copies of course and assessment Ruby/YAML config files that the Rails process writes to. They are **excluded** from `FilesystemEnforcer.fix_tree` by a safety guard (`FilesystemEnforcer.fix_path` refuses to operate on paths outside `courses/`).

| Property    | Value                                         |
|-------------|-----------------------------------------------|
| Owner       | Rails service user (`app`)                    |
| Group       | `autolab` (or value of `COURSE_FS_GROUP` env var) |
| Mode        | `0775` (`drwxrwxr-x`)                         |
| Why permissive? | Rails must be able to write config files here at any time, and no student submission data lives here |

#### SSH User Home Directories

Each staff member who adds an SSH key gets a Unix user account created on-demand. Their home directory follows the standard Linux home layout:

| Path                            | Owner       | Group       | Mode   | Notes |
|---------------------------------|-------------|-------------|--------|-------|
| `/home/<username>/`             | `<username>` | `<username>` | (default) | Standard home dir |
| `/home/<username>/.ssh/`        | `<username>` | `<username>` | `700`  | SSH dir; no group or world access |
| `/home/<username>/.ssh/authorized_keys` | `<username>` | `<username>` | `600` | Private to the user only |
| `/home/<username>/courses` (symlink) | `<username>` | `<username>` | — | Symlink → `courses/` inside the Docker volume for SSH-based file access |

The `0700` / `0600` permissions on `.ssh` and `authorized_keys` are required by `sshd`; relaxing them will cause SSH to reject the key file.

### Unix Group Naming

Course Unix groups are derived from the course name by `UnixGroupManager.safe_group_name`:

1. Strip and replace any character outside `[A-Za-z0-9._-]` with `-`.
2. Truncate to 32 characters (Linux group name limit).
3. If the result starts with `-` or `.`, prepend `grp-`.

Example: course `15-122 Principles` → group `15-122-Principles` (truncated if over 32 chars).

### Who Belongs to a Course Unix Group

| Entity              | Member of course group? | Notes |
|---------------------|------------------------|-------|
| Instructors         | ✅ Yes                 | Added when CUD is created or SSH key is first registered |
| Course Assistants   | ❌ No                  | CAs cannot SSH; no Unix group membership or SSH key provisioning |
| Students            | ❌ No                  | Never added; `courses/<name>/` is `---` to world |
| Rails service user  | ✅ Yes                 | Added via `ensure_service_user_group_membership!` after course creation |
| `root`              | N/A                    | Owns course dirs; bypasses group check via uid 0 |

When assigning permissions, we follow the **Principle of Least Privilege**, or the minimum permissions necessary for a process to perform its job. Only **instructors** (not course assistants) are granted Unix group membership. This means only instructors can SSH into the server or have SSH keys registered. Staff membership is updated whenever an instructor CUD is saved (`after_update :update_unix_group_and_fix_permissions`) or destroyed (`after_destroy :cleanup_unix_group_membership`). If an instructor's Unix user does not yet exist (no SSH key registered), the group membership record is deferred until the key is added.

### Privilege Delegation (UnixOps Daemon)

Because the Rails container process does not run as `root`, all `chown`/`chgrp`/`chmod` operations that require elevated privilege are **delegated** to a separate `unix_ops_daemon.rb` container that has access to the host `/etc` and `/home`. Communication is over an internal HTTP endpoint (`UNIX_OPS_DELEGATE_URL`), authenticated via a shared secret (`UNIX_OPS_SHARED_SECRET`) in a `Bearer` token.

The daemon exposes the following privileged operations:

| Action                  | Effect                                                |
|-------------------------|-------------------------------------------------------|
| `ensure_group`          | `groupadd <course-group>` if it doesn't exist         |
| `remove_group`          | `groupdel <course-group>` if empty (or forced)        |
| `ensure_user`           | `useradd -m -s /bin/bash -p '*' <username>`           |
| `setup_user_home`       | Create `.ssh/`, `authorized_keys` with `700`/`600`    |
| `add_user_to_group`     | `usermod -a -G <group> <username>`                    |
| `remove_user_from_group`| `gpasswd -d <username> <group>`                       |
| `chgrp`                 | `File.chown(owner_uid, gid, path)` — sets owner+group |
| `chmod`                 | `File.chmod(mode, path)` (skips symlinks)             |
| `provision_ssh_key`     | Appends a public key to `authorized_keys`             |
| `deprovision_ssh_key`   | Removes a key by SHA-256 fingerprint                  |
| `delete_user`           | `userdel -r <username>`                               |

If `UNIX_OPS_DELEGATE_URL` is not set, `UnixGroupManager` falls back to running these operations directly in-process (requires the Rails process itself to have the necessary Unix privileges).

---

## Disabled Courses

When a course is disabled by an instructor:

- Non-instructor users (`!@cud.has_auth_level?(:instructor)`) are redirected away with an error message.
- The course remains accessible to instructors and administrators.
- The API enforces the same restriction via `authorize_user_for_course`.

---

## Summary Table

| Resource / Action         | Student | Course Assistant | Instructor | Administrator |
|---------------------------|:-------:|:----------------:|:----------:|:-------------:|
| View released assessment  | ✅      | ✅               | ✅         | ✅            |
| View unreleased assessment| ❌      | ❌               | ✅         | ✅            |
| Submit (handin)           | ✅      | ✅               | ✅         | ✅            |
| Create assessment         | ❌      | ❌               | ✅         | ✅            |
| Delete assessment         | ❌      | ❌               | ✅         | ✅            |
| View own submission       | ✅      | ✅               | ✅         | ✅            |
| View others' submissions  | ❌      | ✅               | ✅         | ✅            |
| Delete submission         | ❌      | ❌               | ✅         | ✅            |
| Enter/edit scores         | ❌      | ✅               | ✅         | ✅            |
| Release section grades    | ❌      | ✅               | ✅         | ✅            |
| Release all grades        | ❌      | ❌               | ✅         | ✅            |
| Manage course users       | ❌      | ❌               | ✅         | ✅            |
| Edit course settings      | ❌      | ❌               | ✅         | ✅            |
| Create course             | ❌      | ❌               | ❌         | ✅            |
| Delete course             | ❌      | ❌               | ❌         | ✅            |
| Delete user account       | ❌      | ❌               | ❌         | ✅            |
| System configuration      | ❌      | ❌               | ❌         | ✅            |
| Sudo (impersonate)        | ❌      | ❌               | ✅ (non-admin only) | ✅ (anyone) |
