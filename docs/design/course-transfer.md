# Course archives

The non-legacy transfer implementation is `CourseArchive`. The old `CourseTransfer` services have been removed. Legacy export and `create_from_tar` remain separate.

## Public API

```ruby
CourseArchive.export(course:, tar_path:, user_ids: [], assessment_ids: [])
CourseArchive.import(tar_path:, identifier:, display_name:, instructor_email:,
                     user_ids: [], assessment_ids: [])
```

Export selections are source user/assessment IDs. Import selections are the IDs shown in the archive preview. Empty arrays mean none; invalid or unavailable IDs are errors. Instructor authorization is required for export; administrator authorization is required for import.

## Modules

| Module | Responsibility |
| --- | --- |
| `CourseArchive` | Public entry points, version, ordered table list, temporary directories. |
| `Selection` | Explicit SQL queries for export and explicit row filters for import. |
| `Records` | YAML arrays, manifest, browser preview, field/reference/path checks. |
| `Content` | Course material, assessment material, user handins, attachment bytes. |
| `Tarball` | Regular-file tar I/O, path containment, link rejection, size limits. |
| `Paths` | Shared validation for relative paths, filenames, and identifiers. |
| `Restore` | Database ID remapping, destination overrides, initialization, rollback cleanup. |

Each model declares `COURSE_EXPORT_FIELDS` and `COURSE_EXPORT_REFERENCES`. The latter maps foreign-key fields to table names. There are no table descriptors, dependency callbacks, graph walks, natural-key matching rules, or export-side ID maps. Table insertion follows the single ordered list in `CourseArchive::TABLES`.

Adding a table means adding its two declarations, its table-list entry, its export query, and its import filter. This maintenance is explicit.

## Version 3 format

The download is an uncompressed tar containing:

```text
manifest.yml                   # format, version, ordered parts
preview.json                   # version, selectable users/assessments
<table>.yml                    # one YAML array per supported table; [] when empty
files/course/                  # shared course files, including custom course.rb
files/assessments/<id>/         # assessment material, without handin data
files/handins/<assessment-id>/<user-id>/
files/attachments/<attachment-id>/<filename>
```

Rows contain `_id` and their model's declared fields. `_id` is the source primary key, used only as an opaque archive key. References are scalar integer archive keys; the model declaration supplies the target table. For example, a problem's `assessment_id: 41` refers to the assessment with `_id: 41`. Keys need not be contiguous. Import always allocates fresh database IDs and remaps references.

Timestamps are ISO strings. YAML contains ordinary values, with no Ruby object tags or aliases. Credentials, global account privileges, external integrations, Unix identities, and Active Storage database internals are excluded by the field allowlists.

Version 1/2 non-legacy archives must be re-exported. They are rejected explicitly, without falling back to legacy import. The legacy format remains supported by the existing legacy path. There is no compatibility adapter inside the new implementation.

## Selection

The course is always included. Users bring only their membership in that course. Assessments bring their problems, autograder settings, scoreboard, and attachments. Course-level attachments and course container definitions are always included.

Submissions, assessment-user rows, and extensions require both a selected owner and selected assessment. Scores and annotations require a selected submission. Groups come only from selected assessment-user rows. Adjustments come only from the selected course, assessments, memberships, and submissions.

A selection never grows to satisfy a reference. Broken required references fail validation. Unselected submitters become null; unselected graders become `0`. Score grader sentinels `0` and `-1` are preserved. Annotation author email remains historical text. Partial groups retain only selected members.

## Files

Shared course files and selected assessment materials are copied independently of handins. A filename containing an excluded email is still shared material; filenames are not used to guess ownership.

Handin payloads are stored under assessment/user IDs. Selected user directories retain their auxiliary files. Known legacy flat submission, annotated-handin, and feedback files are read through the submission model's path helpers and normalized into the same user-owned layout. Unowned flat files and the handin root's deleted-submission archive are omitted.

Selective import copies only the chosen assessment/user payloads. It does not copy everything and delete excluded paths afterward. Attachment bytes are uploaded through Active Storage. Missing files are omitted during export and skipped during import; their submission and attachment records are preserved. Symbolic links and other non-regular files are still rejected.

## Restoration

Import creates a new, disabled course with the requested identifier/display name and active instructor. Dates and academic history are preserved. Existing accounts are reused by case-insensitive email without modifying their profiles; new accounts receive random passwords. Course-owned rows and groups are fresh.

Self-enrollment codes, remote handin destinations, submission job IDs, and image runtime state are reset. Group submission keys are regenerated consistently within each import. Container Dockerfile definitions are restored as drafts; import does not contact Tango or launch builds. Images must be rebuilt or selected on the destination.

Records are inserted without live submission callbacks or notifications. One initialization phase fills missing assessment-user pairs, generates configs and quiz files, initializes attachment slugs, sets course Unix access, loads custom Ruby configuration, and applies destination permissions.

Database changes are transactional. A failed attempt removes only its claimed course directory, generated config files, uploaded blobs, and staff memberships. An existing course/directory/config is never overwritten. A per-identifier file lock prevents concurrent imports from using the same configuration name. Cleanup failures are logged. Filesystem and Unix effects are compensated for caught errors; process-crash recovery and undoing arbitrary custom Ruby effects are outside this implementation.

Archive limits apply on both write and extraction: 10,000 entries, 256 MiB per file, and 1 GiB total, configurable through the existing `AUTOLAB_COURSE_TRANSFER_MAX_*` variables. Combined table YAML is limited to 64 MiB. Links, special files, traversal, duplicate paths, and file/directory conflicts are rejected.

The retained transfer tests are small export unit tests in `spec/services/course_archive/export_spec.rb`. Broader import and round-trip verification is kept outside the reviewable suite.
