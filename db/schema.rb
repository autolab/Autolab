# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2022_09_29_205611) do

  create_table "annotations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
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
  end

  create_table "announcements", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.timestamp "start_date"
    t.timestamp "end_date"
    t.integer "course_user_datum_id"
    t.integer "course_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "persistent", default: false, null: false
    t.boolean "system", default: false, null: false
  end

  create_table "assessment_user_data", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "course_user_datum_id", null: false
    t.integer "assessment_id", null: false
    t.integer "latest_submission_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "grade_type", default: 0, null: false
    t.string "repository"
    t.integer "group_id"
    t.integer "membership_status", limit: 1, default: 0
    t.index ["assessment_id"], name: "index_assessment_user_data_on_assessment_id"
    t.index ["course_user_datum_id", "assessment_id"], name: "index_AUDs_on_CUD_id_and_assessment_id"
    t.index ["course_user_datum_id"], name: "index_assessment_user_data_on_course_user_datum_id"
    t.index ["latest_submission_id"], name: "index_assessment_user_data_on_latest_submission_id", unique: true
  end

  create_table "assessments", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.timestamp "due_at"
    t.timestamp "end_at"
    t.timestamp "visible_at"
    t.timestamp "start_at"
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
    t.datetime "grading_deadline", null: false
    t.boolean "has_autograde_old"
    t.boolean "has_scoreboard_old"
    t.boolean "has_svn"
    t.boolean "quiz", default: false
    t.text "quizData"
    t.string "remote_handin_path"
    t.string "category_name"
    t.integer "group_size", default: 1
    t.boolean "has_custom_form", default: false
    t.text "languages"
    t.text "textfields"
    t.text "embedded_quiz_form_data"
    t.boolean "embedded_quiz"
    t.binary "embedded_quiz_form"
    t.boolean "github_submission_enabled", default: true
    t.boolean "allow_student_assign_group", default: true
    t.boolean "is_positive_grading", default: false
  end

  create_table "attachments", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "filename"
    t.string "mime_type"
    t.boolean "released"
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "course_id"
    t.integer "assessment_id"
    t.index ["assessment_id"], name: "index_attachments_on_assessment_id"
  end

  create_table "authentications", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "provider", null: false
    t.string "uid", null: false
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "autograders", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "assessment_id"
    t.integer "autograde_timeout"
    t.string "autograde_image"
    t.boolean "release_score"
  end

  create_table "course_user_data", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
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
  end

  create_table "courses", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
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
  end

  create_table "extensions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "course_user_datum_id"
    t.integer "assessment_id"
    t.integer "days"
    t.boolean "infinite", default: false, null: false
  end

  create_table "github_integrations", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "oauth_state"
    t.text "access_token_ciphertext"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["oauth_state"], name: "index_github_integrations_on_oauth_state", unique: true
    t.index ["user_id"], name: "index_github_integrations_on_user_id", unique: true
  end

  create_table "groups", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "module_data", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "field_id"
    t.integer "data_id"
    t.binary "data"
  end

  create_table "module_fields", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "user_module_id"
    t.string "name"
    t.string "data_type"
  end

  create_table "oauth_access_grants", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "resource_owner_id", null: false
    t.integer "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes"
    t.index ["application_id"], name: "fk_rails_b4b53e07b8"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "resource_owner_id"
    t.integer "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "fk_rails_732cb83ab7"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
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

  create_table "oauth_device_flow_requests", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "application_id", null: false
    t.string "scopes", default: "", null: false
    t.string "device_code", null: false
    t.string "user_code", null: false
    t.datetime "requested_at", null: false
    t.integer "resolution", default: 0, null: false
    t.datetime "resolved_at"
    t.integer "resource_owner_id"
    t.string "access_code"
    t.index ["application_id"], name: "fk_rails_4035c6e0ed"
    t.index ["device_code"], name: "index_oauth_device_flow_requests_on_device_code", unique: true
    t.index ["user_code"], name: "index_oauth_device_flow_requests_on_user_code", unique: true
  end

  create_table "problems", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "assessment_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float "max_score", default: 0.0
    t.boolean "optional", default: false
  end

  create_table "risk_conditions", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "condition_type"
    t.text "parameters"
    t.integer "version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "course_id"
  end

  create_table "scheduler", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "action"
    t.timestamp "next"
    t.integer "interval"
    t.integer "course_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "score_adjustments", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "kind", null: false
    t.float "value", null: false
    t.string "type", default: "Tweak", null: false
  end

  create_table "scoreboards", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "assessment_id"
    t.text "banner"
    t.text "colspec"
  end

  create_table "scores", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
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

  create_table "submissions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
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
    t.text "settings"
    t.text "embedded_quiz_form_answer"
    t.integer "submitted_by_app_id"
    t.string "group_key", default: ""
    t.index ["assessment_id"], name: "index_submissions_on_assessment_id"
    t.index ["course_user_datum_id"], name: "index_submissions_on_course_user_datum_id"
  end

  create_table "users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
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
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "watchlist_configurations", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.json "category_blocklist"
    t.json "assessment_blocklist"
    t.bigint "course_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id"], name: "index_watchlist_configurations_on_course_id"
  end

  create_table "watchlist_instances", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "course_user_datum_id"
    t.bigint "course_id"
    t.bigint "risk_condition_id"
    t.integer "status", default: 0
    t.boolean "archived", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "violation_info"
    t.index ["course_id"], name: "index_watchlist_instances_on_course_id"
    t.index ["course_user_datum_id"], name: "index_watchlist_instances_on_course_user_datum_id"
    t.index ["risk_condition_id"], name: "index_watchlist_instances_on_risk_condition_id"
  end

  add_foreign_key "github_integrations", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_device_flow_requests", "oauth_applications", column: "application_id"
end
