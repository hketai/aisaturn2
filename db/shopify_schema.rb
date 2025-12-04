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

ActiveRecord::Schema[7.1].define(version: 2025_01_20_000002) do
  create_schema "auth"
  create_schema "extensions"
  create_schema "graphql"
  create_schema "graphql_public"
  create_schema "pgbouncer"
  create_schema "realtime"
  create_schema "storage"
  create_schema "vault"

  # These extensions should be enabled to support this database
  enable_extension "pg_graphql"
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "supabase_vault"
  enable_extension "uuid-ossp"
  enable_extension "vector"

  create_table "shopify_products", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "hook_id"
    t.bigint "shopify_product_id", null: false
    t.string "title"
    t.text "description"
    t.string "handle"
    t.string "vendor"
    t.string "product_type"
    t.jsonb "variants", default: []
    t.jsonb "images", default: []
    t.decimal "min_price", precision: 10, scale: 2
    t.decimal "max_price", precision: 10, scale: 2
    t.integer "total_inventory", default: 0
    t.vector "embedding", limit: 1536
    t.datetime "last_synced_at"
    t.datetime "last_queried_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "shopify_product_id"], name: "index_shopify_products_on_account_and_shopify_product_id", unique: true
    t.index ["account_id"], name: "index_shopify_products_on_account_id"
    t.index ["embedding"], name: "index_shopify_products_on_embedding", using: :ivfflat
    t.index ["hook_id"], name: "index_shopify_products_on_hook_id"
    t.index ["last_queried_at"], name: "index_shopify_products_on_last_queried_at"
    t.index ["last_synced_at"], name: "index_shopify_products_on_last_synced_at"
  end

  create_table "shopify_sync_statuses", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "hook_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "total_products", default: 0
    t.integer "synced_products", default: 0
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "hook_id"], name: "index_shopify_sync_statuses_on_account_and_hook"
    t.index ["created_at"], name: "index_shopify_sync_statuses_on_created_at"
    t.index ["status"], name: "index_shopify_sync_statuses_on_status"
  end

end
