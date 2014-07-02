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

ActiveRecord::Schema.define(version: 20140701052200) do

  create_table "hotels", force: true do |t|
    t.string   "name"
    t.float    "rating"
    t.integer  "review_count"
    t.text     "location"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "traveler_rating"
    t.string   "rating_summary"
    t.string   "format_address"
    t.string   "street_address"
    t.string   "star_rating"
    t.string   "tag"
  end

  create_table "reviews", force: true do |t|
    t.integer  "review_id"
    t.integer  "hotel_id"
    t.string   "title"
    t.text     "content"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
