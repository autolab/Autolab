# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170101140555) do

  create_table "annotations", force: :cascade do |t|
    t.integer  "submission_id", limit: 4
    t.string   "filename",      limit: 255
    t.integer  "position",      limit: 4
    t.integer  "line",          limit: 4
    t.string   "text",          limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "submitted_by",  limit: 255
    t.text     "comment",       limit: 65535
    t.float    "value",         limit: 24
    t.integer  "problem_id",    limit: 4
    t.string   "coordinate",    limit: 255
  end

  create_table "announcements", force: :cascade do |t|
    t.string   "title",                limit: 255
    t.text     "description",          limit: 65535
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer  "course_user_datum_id", limit: 4
    t.integer  "course_id",            limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "persistent",           limit: 1,     default: false, null: false
    t.boolean  "system",               limit: 1,     default: false, null: false
  end

  create_table "assessment_user_data", force: :cascade do |t|
    t.integer  "course_user_datum_id", limit: 4,               null: false
    t.integer  "assessment_id",        limit: 4,               null: false
    t.integer  "latest_submission_id", limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "grade_type",           limit: 4,   default: 0, null: false
    t.string   "repository",           limit: 255
    t.integer  "group_id",             limit: 4
    t.integer  "membership_status",    limit: 1,   default: 0
  end

  add_index "assessment_user_data", ["assessment_id"], name: "index_assessment_user_data_on_assessment_id", using: :btree
  add_index "assessment_user_data", ["course_user_datum_id", "assessment_id"], name: "index_AUDs_on_CUD_id_and_assessment_id", using: :btree
  add_index "assessment_user_data", ["course_user_datum_id"], name: "index_assessment_user_data_on_course_user_datum_id", using: :btree
  add_index "assessment_user_data", ["latest_submission_id"], name: "index_assessment_user_data_on_latest_submission_id", unique: true, using: :btree

  create_table "assessments", force: :cascade do |t|
    t.datetime "due_at"
    t.datetime "end_at"
    t.datetime "visible_at"
    t.datetime "start_at"
    t.string   "name",                    limit: 255
    t.text     "description",             limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "course_id",               limit: 4
    t.string   "display_name",            limit: 255
    t.string   "handin_filename",         limit: 255
    t.string   "handin_directory",        limit: 255
    t.integer  "max_grace_days",          limit: 4,     default: 0
    t.string   "handout",                 limit: 255
    t.string   "writeup",                 limit: 255
    t.boolean  "allow_unofficial",        limit: 1
    t.integer  "max_submissions",         limit: 4,     default: -1
    t.boolean  "disable_handins",         limit: 1
    t.boolean  "exam",                    limit: 1,     default: false
    t.integer  "max_size",                limit: 4,     default: 2
    t.integer  "version_threshold",       limit: 4
    t.integer  "late_penalty_id",         limit: 4
    t.integer  "version_penalty_id",      limit: 4
    t.datetime "grading_deadline",                                      null: false
    t.boolean  "has_autograde_old",       limit: 1
    t.boolean  "has_scoreboard_old",      limit: 1
    t.boolean  "has_svn",                 limit: 1
    t.boolean  "quiz",                    limit: 1,     default: false
    t.text     "quizData",                limit: 65535
    t.string   "remote_handin_path",      limit: 255
    t.string   "category_name",           limit: 255
    t.integer  "group_size",              limit: 4,     default: 1
    t.boolean  "has_custom_form",         limit: 1,     default: false
    t.text     "languages",               limit: 65535
    t.text     "textfields",              limit: 65535
    t.text     "embedded_quiz_form_data", limit: 65535
    t.boolean  "embedded_quiz",           limit: 1
    t.binary   "embedded_quiz_form",      limit: 65535
  end

  create_table "attachments", force: :cascade do |t|
    t.string   "filename",      limit: 255
    t.string   "mime_type",     limit: 255
    t.boolean  "released",      limit: 1
    t.string   "name",          limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "course_id",     limit: 4
    t.integer  "assessment_id", limit: 4
  end

  add_index "attachments", ["assessment_id"], name: "index_attachments_on_assessment_id", using: :btree

  create_table "authentications", force: :cascade do |t|
    t.string   "provider",   limit: 255, null: false
    t.string   "uid",        limit: 255, null: false
    t.integer  "user_id",    limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "autograders", force: :cascade do |t|
    t.integer "assessment_id",     limit: 4
    t.integer "autograde_timeout", limit: 4
    t.string  "autograde_image",   limit: 255
    t.boolean "release_score",     limit: 1
  end

  create_table "course_user_data", force: :cascade do |t|
    t.string   "lecture",          limit: 255
    t.string   "section",          limit: 255, default: ""
    t.string   "grade_policy",     limit: 255, default: ""
    t.integer  "course_id",        limit: 4,                   null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "instructor",       limit: 1,   default: false
    t.boolean  "dropped",          limit: 1,   default: false
    t.string   "nickname",         limit: 255
    t.boolean  "course_assistant", limit: 1,   default: false
    t.integer  "tweak_id",         limit: 4
    t.integer  "user_id",          limit: 4,                   null: false
  end

  create_table "courses", force: :cascade do |t|
    t.string   "name",                          limit: 255
    t.string   "semester",                      limit: 255
    t.integer  "late_slack",                    limit: 4
    t.integer  "grace_days",                    limit: 4
    t.string   "display_name",                  limit: 255
    t.date     "start_date"
    t.date     "end_date"
    t.boolean  "disabled",                      limit: 1,     default: false
    t.boolean  "exam_in_progress",              limit: 1,     default: false
    t.integer  "version_threshold",             limit: 4,     default: -1,    null: false
    t.integer  "late_penalty_id",               limit: 4
    t.integer  "version_penalty_id",            limit: 4
    t.datetime "cgdub_dependencies_updated_at"
    t.text     "gb_message",                    limit: 65535
  end

  create_table "extensions", force: :cascade do |t|
    t.integer "course_user_datum_id", limit: 4
    t.integer "assessment_id",        limit: 4
    t.integer "days",                 limit: 4
    t.boolean "infinite",             limit: 1, default: false, null: false
  end

  create_table "groups", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "module_data", force: :cascade do |t|
    t.integer "field_id", limit: 4
    t.integer "data_id",  limit: 4
    t.binary  "data",     limit: 65535
  end

  create_table "module_fields", force: :cascade do |t|
    t.integer "user_module_id", limit: 4
    t.string  "name",           limit: 255
    t.string  "data_type",      limit: 255
  end

  create_table "problems", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.text     "description",   limit: 65535
    t.integer  "assessment_id", limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "max_score",     limit: 24,    default: 0.0
    t.boolean  "optional",      limit: 1,     default: false
  end

  create_table "scheduler", force: :cascade do |t|
    t.string   "action",     limit: 255
    t.datetime "next"
    t.integer  "interval",   limit: 4
    t.integer  "course_id",  limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "score_adjustments", force: :cascade do |t|
    t.integer "kind",  limit: 4,                     null: false
    t.float   "value", limit: 24,                    null: false
    t.string  "type",  limit: 255, default: "Tweak", null: false
  end

  create_table "scoreboards", force: :cascade do |t|
    t.integer "assessment_id", limit: 4
    t.text    "banner",        limit: 65535
    t.text    "colspec",       limit: 65535
  end

  create_table "scores", force: :cascade do |t|
    t.integer  "submission_id", limit: 4
    t.float    "score",         limit: 24
    t.text     "feedback",      limit: 16777215
    t.integer  "problem_id",    limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "released",      limit: 1,        default: false
    t.integer  "grader_id",     limit: 4
  end

  add_index "scores", ["problem_id", "submission_id"], name: "problem_submission_unique", unique: true, using: :btree
  add_index "scores", ["submission_id"], name: "index_scores_on_submission_id", using: :btree

  create_table "submissions", force: :cascade do |t|
    t.integer  "version",                   limit: 4
    t.integer  "course_user_datum_id",      limit: 4
    t.integer  "assessment_id",             limit: 4
    t.string   "filename",                  limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "notes",                     limit: 255,   default: ""
    t.string   "mime_type",                 limit: 255
    t.integer  "special_type",              limit: 4,     default: 0
    t.integer  "submitted_by_id",           limit: 4
    t.text     "autoresult",                limit: 65535
    t.string   "detected_mime_type",        limit: 255
    t.string   "submitter_ip",              limit: 40
    t.integer  "tweak_id",                  limit: 4
    t.boolean  "ignored",                   limit: 1,     default: false, null: false
    t.string   "dave",                      limit: 255
    t.text     "settings",                  limit: 65535
    t.text     "embedded_quiz_form_answer", limit: 65535
  end

  add_index "submissions", ["assessment_id"], name: "index_submissions_on_assessment_id", using: :btree
  add_index "submissions", ["course_user_datum_id"], name: "index_submissions_on_course_user_datum_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                  limit: 255, default: "",    null: false
    t.string   "first_name",             limit: 255, default: "",    null: false
    t.string   "last_name",              limit: 255, default: "",    null: false
    t.boolean  "administrator",          limit: 1,   default: false, null: false
    t.string   "encrypted_password",     limit: 255, default: "",    null: false
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          limit: 4,   default: 0,     null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.string   "confirmation_token",     limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email",      limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "school",                 limit: 255
    t.string   "major",                  limit: 255
    t.string   "year",                   limit: 255
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

end
