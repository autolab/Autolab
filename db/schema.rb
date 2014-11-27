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

ActiveRecord::Schema.define(version: 20141125044705) do

  create_table "annotations", force: true do |t|
    t.integer  "submission_id"
    t.string   "filename"
    t.integer  "position"
    t.integer  "line"
    t.string   "text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "submitted_by"
    t.text     "comment"
    t.float    "value",         limit: 24
    t.integer  "problem_id"
  end

  create_table "announcements", force: true do |t|
    t.string   "title"
    t.text     "description"
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer  "course_user_datum_id"
    t.integer  "course_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "persistent",           default: false, null: false
    t.boolean  "system",               default: false, null: false
  end

  create_table "assessment_categories", force: true do |t|
    t.string  "name"
    t.integer "course_id"
  end

  create_table "assessment_user_data", force: true do |t|
    t.integer  "course_user_datum_id",             null: false
    t.integer  "assessment_id",                    null: false
    t.integer  "latest_submission_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "grade_type",           default: 0, null: false
  end

  add_index "assessment_user_data", ["assessment_id"], name: "index_assessment_user_data_on_assessment_id", using: :btree
  add_index "assessment_user_data", ["course_user_datum_id", "assessment_id"], name: "index_AUDs_on_CUD_id_and_assessment_id", using: :btree
  add_index "assessment_user_data", ["course_user_datum_id"], name: "index_assessment_user_data_on_course_user_datum_id", using: :btree
  add_index "assessment_user_data", ["latest_submission_id"], name: "index_assessment_user_data_on_latest_submission_id", unique: true, using: :btree

  create_table "assessments", force: true do |t|
    t.datetime "due_at"
    t.datetime "end_at"
    t.datetime "visible_at"
    t.datetime "start_at"
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "course_id"
    t.string   "display_name"
    t.integer  "category_id"
    t.string   "handin_filename"
    t.string   "handin_directory"
    t.integer  "max_grace_days",                 default: 0
    t.string   "handout"
    t.string   "writeup"
    t.boolean  "allow_unofficial"
    t.integer  "max_submissions",                default: -1
    t.boolean  "disable_handins"
    t.boolean  "exam",                           default: false
    t.integer  "max_size",                       default: 2
    t.float    "late_penalty_old",    limit: 24
    t.integer  "version_threshold"
    t.float    "version_penalty_old", limit: 24
    t.integer  "late_penalty_id"
    t.integer  "version_penalty_id"
    t.datetime "grading_deadline",                               null: false
    t.boolean  "has_autograde"
    t.boolean  "has_partners"
    t.boolean  "has_scoreboard"
    t.boolean  "has_svn"
    t.boolean  "quiz",                           default: false
    t.text     "quizData"
  end

  create_table "attachments", force: true do |t|
    t.string   "filename"
    t.string   "mime_type"
    t.boolean  "released"
    t.string   "type_old"
    t.integer  "foreign_key_old"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "course_id"
    t.integer  "assessment_id"
  end

  add_index "attachments", ["assessment_id"], name: "index_attachments_on_assessment_id", using: :btree

  create_table "authentications", force: true do |t|
    t.string   "provider",   null: false
    t.string   "uid",        null: false
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "autograding_setups", force: true do |t|
    t.integer "assessment_id"
    t.integer "autograde_timeout"
    t.string  "autograde_image"
    t.boolean "release_score"
  end

  create_table "course_user_data", force: true do |t|
    t.string   "first_name_backup",               default: ""
    t.string   "last_name_backup",                default: ""
    t.string   "andrewID_backup",                 default: ""
    t.string   "school_backup",                   default: ""
    t.string   "major_backup",                    default: ""
    t.string   "year_backup"
    t.string   "lecture"
    t.string   "section",                         default: ""
    t.string   "grade_policy",                    default: ""
    t.integer  "course_id",                                       null: false
    t.string   "email_backup",                    default: ""
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "instructor",                      default: false
    t.boolean  "administrator_backup",            default: false
    t.boolean  "dropped",                         default: false
    t.string   "nickname"
    t.boolean  "course_assistant",                default: false
    t.float    "tweak_old",            limit: 24, default: 0.0
    t.boolean  "absolute_tweak",                  default: true
    t.integer  "tweak_id"
    t.integer  "user_id",                                         null: false
  end

  create_table "courses", force: true do |t|
    t.string   "name"
    t.string   "semester"
    t.integer  "late_slack"
    t.integer  "grace_days"
    t.float    "late_penalty_old",              limit: 24
    t.string   "display_name"
    t.date     "start_date"
    t.date     "end_date"
    t.boolean  "disabled",                                 default: false
    t.boolean  "exam_in_progress",                         default: false
    t.integer  "version_threshold",                        default: -1,    null: false
    t.float    "version_penalty_old",           limit: 24, default: 0.0,   null: false
    t.integer  "late_penalty_id"
    t.integer  "version_penalty_id"
    t.datetime "cgdub_dependencies_updated_at"
    t.text     "gb_message"
  end

  create_table "extensions", force: true do |t|
    t.integer "course_user_datum_id"
    t.integer "assessment_id"
    t.integer "days"
    t.boolean "infinite",             default: false, null: false
  end

  create_table "module_data", force: true do |t|
    t.integer "field_id"
    t.integer "data_id"
    t.binary  "data"
  end

  create_table "module_fields", force: true do |t|
    t.integer "user_module_id"
    t.string  "name"
    t.string  "data_type"
  end

  create_table "problems", force: true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "assessment_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "max_score",     limit: 24, default: 0.0
    t.boolean  "optional",                 default: false
  end

  create_table "scheduler", force: true do |t|
    t.string   "action"
    t.datetime "next"
    t.integer  "interval"
    t.integer  "course_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "score_adjustments", force: true do |t|
    t.integer "kind",                               null: false
    t.float   "value", limit: 24,                   null: false
    t.string  "type",             default: "Tweak", null: false
  end

  create_table "scoreboard_setups", force: true do |t|
    t.integer "assessment_id"
    t.string  "banner"
    t.string  "colspec"
  end

  create_table "scores", force: true do |t|
    t.integer  "submission_id"
    t.float    "score",              limit: 24
    t.text     "feedback"
    t.integer  "problem_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "released",                              default: false
    t.integer  "grader_id"
    t.binary   "feedback_file",      limit: 2147483647
    t.string   "feedback_file_type"
    t.string   "feedback_file_name"
  end

  add_index "scores", ["problem_id", "submission_id"], name: "problem_submission_unique", unique: true, using: :btree
  add_index "scores", ["submission_id"], name: "index_scores_on_submission_id", using: :btree

  create_table "submissions", force: true do |t|
    t.integer  "version"
    t.integer  "course_user_datum_id"
    t.integer  "assessment_id"
    t.string   "filename"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "notes",                           default: ""
    t.float    "tweak_old",            limit: 24, default: 0.0
    t.string   "mime_type"
    t.integer  "special_type",                    default: 0
    t.integer  "submitted_by_id"
    t.text     "autoresult"
    t.boolean  "absolute_tweak",                  default: true,  null: false
    t.string   "detected_mime_type"
    t.string   "submitter_ip",         limit: 40
    t.integer  "tweak_id"
    t.boolean  "ignored_old",                     default: false, null: false
    t.boolean  "ignored",                         default: false, null: false
  end

  add_index "submissions", ["assessment_id"], name: "index_submissions_on_assessment_id", using: :btree
  add_index "submissions", ["course_user_datum_id"], name: "index_submissions_on_course_user_datum_id", using: :btree

  create_table "user_modules", force: true do |t|
    t.integer "course_id"
    t.string  "name"
  end

  create_table "users", force: true do |t|
    t.string   "email",                  default: "",    null: false
    t.string   "first_name",             default: "",    null: false
    t.string   "last_name",              default: "",    null: false
    t.boolean  "administrator",          default: false, null: false
    t.string   "encrypted_password",     default: "",    null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,     null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "school"
    t.string   "major"
    t.string   "year"
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

end
