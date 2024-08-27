# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2024_04_06_174050) do

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "annotations", force: :cascade do |t|
    t.integer "submission_id"
    t.string "filename"
    t.integer "position"
    t.integer "line"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "submitted_by"
    t.text "comment"
    t.float "value"
    t.integer "problem_id"
    t.string "coordinate"
    t.boolean "shared_comment", default: false
    t.boolean "global_comment", default: false
  end

  create_table "announcements", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer "course_user_datum_id"
    t.integer "course_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "persistent", default: false, null: false
    t.boolean "system", default: false, null: false
  end

  create_table "assessment_user_data", force: :cascade do |t|
    t.integer "course_user_datum_id", null: false
    t.integer "assessment_id", null: false
    t.integer "latest_submission_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "grade_type", default: 0, null: false
    t.integer "group_id"
    t.integer "membership_status", limit: 1, default: 0
    t.integer "version_number"
    t.index ["assessment_id"], name: "index_assessment_user_data_on_assessment_id"
    t.index ["course_user_datum_id", "assessment_id"], name: "index_AUDs_on_CUD_id_and_assessment_id"
    t.index ["course_user_datum_id"], name: "index_assessment_user_data_on_course_user_datum_id"
    t.index ["latest_submission_id"], name: "index_assessment_user_data_on_latest_submission_id", unique: true
  end

  create_table "assessments", force: :cascade do |t|
    t.datetime "due_at"
    t.datetime "end_at"
    t.datetime "start_at"
    t.string "name"
    t.text "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "course_id"
    t.string "display_name"
    t.string "handin_filename"
    t.string "handin_directory"
    t.integer "max_grace_days", default: 0
    t.string "handout"
    t.string "writeup"
    t.boolean "allow_unofficial"
    t.integer "max_submissions", default: -1
    t.boolean "disable_handins"
    t.boolean "exam", default: false
    t.integer "max_size", default: 2
    t.integer "version_threshold"
    t.integer "late_penalty_id"
    t.integer "version_penalty_id"
    t.boolean "quiz", default: false
    t.text "quizData"
    t.string "remote_handin_path"
    t.string "category_name"
    t.integer "group_size", default: 1
    t.text "embedded_quiz_form_data"
    t.boolean "embedded_quiz"
    t.boolean "github_submission_enabled", default: true
    t.boolean "allow_student_assign_group", default: true
    t.boolean "is_positive_grading", default: false
    t.boolean "disable_network", default: false
  end

  create_table "attachments", force: :cascade do |t|
    t.string "filename"
    t.string "mime_type"
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "course_id"
    t.integer "assessment_id"
    t.string "category_name", default: "General"
    t.datetime "release_at", default: -> { "CURRENT_TIMESTAMP" }
    t.string "slug"
    t.index ["assessment_id"], name: "index_attachments_on_assessment_id"
    t.index ["slug"], name: "index_attachments_on_slug", unique: true
  end

  create_table "authentications", force: :cascade do |t|
    t.string "provider", null: false
    t.string "uid", null: false
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "autograders", force: :cascade do |t|
    t.integer "assessment_id"
    t.integer "autograde_timeout"
    t.string "autograde_image"
    t.boolean "release_score"
  end

  create_table "course_user_data", force: :cascade do |t|
    t.string "lecture"
    t.string "section", default: ""
    t.string "grade_policy", default: ""
    t.integer "course_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "instructor", default: false
    t.boolean "dropped", default: false
    t.string "nickname"
    t.boolean "course_assistant", default: false
    t.integer "tweak_id"
    t.integer "user_id", null: false
    t.string "course_number", default: ""
  end

  create_table "courses", force: :cascade do |t|
    t.string "name"
    t.string "semester"
    t.integer "late_slack"
    t.integer "grace_days"
    t.string "display_name"
    t.date "start_date"
    t.date "end_date"
    t.boolean "disabled", default: false
    t.boolean "exam_in_progress", default: false
    t.integer "version_threshold", default: -1, null: false
    t.integer "late_penalty_id"
    t.integer "version_penalty_id"
    t.datetime "cgdub_dependencies_updated_at"
    t.text "gb_message"
    t.string "website"
    t.string "access_code"
    t.boolean "disable_on_end", default: false
  end

  create_table "extensions", force: :cascade do |t|
    t.integer "course_user_datum_id"
    t.integer "assessment_id"
    t.integer "days"
    t.boolean "infinite", default: false, null: false
  end

  create_table "friendly_id_slugs", charset: "utf8mb3", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true, length: { slug: 70, scope: 70 }
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type", length: { slug: 140 }
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "github_integrations", force: :cascade do |t|
    t.string "oauth_state"
    t.text "access_token_ciphertext"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["oauth_state"], name: "index_github_integrations_on_oauth_state", unique: true
    t.index ["user_id"], name: "index_github_integrations_on_user_id", unique: true
  end

  create_table "groups", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lti_course_data", force: :cascade do |t|
    t.string "context_id"
    t.integer "course_id"
    t.datetime "last_synced"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "membership_url"
    t.string "platform"
    t.boolean "auto_sync", default: false
    t.boolean "drop_missing_students", default: false
  end

  create_table "module_data", force: :cascade do |t|
    t.integer "field_id"
    t.integer "data_id"
    t.binary "data"
  end

  create_table "module_fields", force: :cascade do |t|
    t.integer "user_module_id"
    t.string "name"
    t.string "data_type"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer "resource_owner_id", null: false
    t.integer "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer "resource_owner_id"
    t.integer "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "confidential", default: true, null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "oauth_device_flow_requests", force: :cascade do |t|
    t.integer "application_id", null: false
    t.string "scopes", default: "", null: false
    t.string "device_code", null: false
    t.string "user_code", null: false
    t.datetime "requested_at", null: false
    t.integer "resolution", default: 0, null: false
    t.datetime "resolved_at"
    t.integer "resource_owner_id"
    t.string "access_code"
    t.index ["device_code"], name: "index_oauth_device_flow_requests_on_device_code", unique: true
    t.index ["user_code"], name: "index_oauth_device_flow_requests_on_user_code", unique: true
  end

  create_table "problems", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "assessment_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float "max_score", default: 0.0
    t.boolean "optional", default: false
    t.boolean "starred", default: false
    t.index ["assessment_id", "name"], name: "problem_uniq", unique: true
  end

  create_table "risk_conditions", force: :cascade do |t|
    t.integer "condition_type"
    t.text "parameters"
    t.integer "version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "course_id"
  end

  create_table "scheduler", force: :cascade do |t|
    t.string "action"
    t.datetime "next"
    t.integer "interval"
    t.integer "course_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "until", default: -> { "CURRENT_TIMESTAMP" }
    t.boolean "disabled", default: false
  end

  create_table "score_adjustments", force: :cascade do |t|
    t.integer "kind", null: false
    t.float "value", null: false
    t.string "type", default: "Tweak", null: false
  end

  create_table "scoreboards", force: :cascade do |t|
    t.integer "assessment_id"
    t.text "banner"
    t.text "colspec"
    t.boolean "include_instructors", default: false
  end

  create_table "scores", force: :cascade do |t|
    t.integer "submission_id"
    t.float "score"
    t.text "feedback", size: :medium
    t.integer "problem_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "released", default: false
    t.integer "grader_id"
    t.index ["problem_id", "submission_id"], name: "problem_submission_unique", unique: true
    t.index ["submission_id"], name: "index_scores_on_submission_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.integer "version"
    t.integer "course_user_datum_id"
    t.integer "assessment_id"
    t.string "filename"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "notes", default: ""
    t.string "mime_type"
    t.integer "special_type", default: 0
    t.integer "submitted_by_id"
    t.text "autoresult"
    t.string "detected_mime_type"
    t.string "submitter_ip", limit: 40
    t.integer "tweak_id"
    t.boolean "ignored", default: false, null: false
    t.string "dave"
    t.text "embedded_quiz_form_answer"
    t.integer "submitted_by_app_id"
    t.string "group_key", default: ""
    t.integer "jobid"
    t.text "missing_problems"
    t.index ["assessment_id"], name: "index_submissions_on_assessment_id"
    t.index ["course_user_datum_id"], name: "index_submissions_on_course_user_datum_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.boolean "administrator", default: false, null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "school"
    t.string "major"
    t.string "year"
    t.boolean "hover_assessment_date", default: false, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "watchlist_configurations", force: :cascade do |t|
    t.json "category_blocklist"
    t.json "assessment_blocklist"
    t.integer "course_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "allow_ca", default: false
    t.index ["course_id"], name: "index_watchlist_configurations_on_course_id"
  end

  create_table "watchlist_instances", force: :cascade do |t|
    t.integer "course_user_datum_id"
    t.integer "course_id"
    t.integer "risk_condition_id"
    t.integer "status", default: 0
    t.boolean "archived", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "violation_info"
    t.index ["course_id"], name: "index_watchlist_instances_on_course_id"
    t.index ["course_user_datum_id"], name: "index_watchlist_instances_on_course_user_datum_id"
    t.index ["risk_condition_id"], name: "index_watchlist_instances_on_risk_condition_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
