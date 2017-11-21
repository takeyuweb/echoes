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

ActiveRecord::Schema.define(version: 20171121194012) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "devices", force: :cascade, comment: "見つかったスマートデバイス" do |t|
    t.string "name", default: "", null: false, comment: "デバイス名"
    t.string "eoj", default: "", null: false, comment: "ECHONETオブジェクト"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "node_id"
    t.index ["node_id", "eoj"], name: "index_devices_on_node_id_and_eoj", unique: true
  end

  create_table "nodes", force: :cascade, comment: "見つかったノード" do |t|
    t.string "name", default: "", null: false, comment: "ノード名"
    t.inet "ipaddr", default: "0.0.0.0", null: false, comment: "IPアドレス"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
