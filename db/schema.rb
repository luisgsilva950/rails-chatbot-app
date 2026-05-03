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

ActiveRecord::Schema[8.1].define(version: 2026_05_03_183927) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointment_photos", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.string "caption"
    t.datetime "created_at", null: false
    t.string "stage", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["appointment_id"], name: "index_appointment_photos_on_appointment_id"
    t.index ["stage"], name: "index_appointment_photos_on_stage"
    t.check_constraint "stage::text = ANY (ARRAY['before'::character varying::text, 'during'::character varying::text, 'after'::character varying::text])", name: "appointment_photos_stage_check"
  end

  create_table "appointments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "employee_id"
    t.text "notes"
    t.datetime "scheduled_at", null: false
    t.bigint "service_type_id", null: false
    t.string "status", default: "scheduled", null: false
    t.integer "total_cents", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["employee_id"], name: "index_appointments_on_employee_id"
    t.index ["scheduled_at", "status"], name: "index_appointments_on_scheduled_at_and_status"
    t.index ["scheduled_at"], name: "index_appointments_on_scheduled_at"
    t.index ["service_type_id"], name: "index_appointments_on_service_type_id"
    t.index ["status"], name: "index_appointments_on_status"
    t.index ["vehicle_id"], name: "index_appointments_on_vehicle_id"
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying::text, 'in_progress'::character varying::text, 'completed'::character varying::text, 'canceled'::character varying::text, 'no_show'::character varying::text])", name: "appointments_status_check"
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "model_id"
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_chats_on_model_id"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "document"
    t.string "email"
    t.string "name", null: false
    t.text "notes"
    t.string "phone", null: false
    t.datetime "updated_at", null: false
    t.index ["document"], name: "index_customers_on_document", unique: true, where: "(document IS NOT NULL)"
    t.index ["email"], name: "index_customers_on_email"
    t.index ["phone"], name: "index_customers_on_phone"
  end

  create_table "employees", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_employees_on_active"
    t.index ["role"], name: "index_employees_on_role"
    t.check_constraint "role::text = ANY (ARRAY['washer'::character varying::text, 'detailer'::character varying::text, 'manager'::character varying::text])", name: "employees_role_check"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.bigint "chat_id", null: false
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.bigint "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.bigint "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_models_on_family"
    t.index ["modalities"], name: "index_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "appointment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "paid_at"
    t.string "payment_method", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_payments_on_appointment_id"
    t.index ["paid_at"], name: "index_payments_on_paid_at"
    t.index ["payment_method"], name: "index_payments_on_payment_method"
    t.index ["status"], name: "index_payments_on_status"
    t.check_constraint "payment_method::text = ANY (ARRAY['cash'::character varying::text, 'debit'::character varying::text, 'credit'::character varying::text, 'pix'::character varying::text])", name: "payments_payment_method_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'paid'::character varying::text, 'refunded'::character varying::text, 'canceled'::character varying::text])", name: "payments_status_check"
  end

  create_table "products", force: :cascade do |t|
    t.string "category", null: false
    t.integer "cost_cents", null: false
    t.datetime "created_at", null: false
    t.integer "min_stock", default: 0, null: false
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.string "sku", null: false
    t.integer "stock_quantity", default: 0, null: false
    t.string "unit", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_products_on_category"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["stock_quantity"], name: "index_products_on_stock_quantity"
    t.check_constraint "category::text = ANY (ARRAY['shampoo'::character varying::text, 'wax'::character varying::text, 'sealant'::character varying::text, 'polish'::character varying::text, 'interior'::character varying::text, 'tool'::character varying::text, 'consumable'::character varying::text])", name: "products_category_check"
    t.check_constraint "unit::text = ANY (ARRAY['ml'::character varying::text, 'l'::character varying::text, 'un'::character varying::text, 'kg'::character varying::text])", name: "products_unit_check"
  end

  create_table "service_types", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_minutes", null: false
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_service_types_on_category"
    t.index ["name"], name: "index_service_types_on_name", unique: true
    t.check_constraint "category::text = ANY (ARRAY['wash'::character varying::text, 'detailing'::character varying::text, 'protection'::character varying::text, 'interior'::character varying::text])", name: "service_types_category_check"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "occurred_at", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.string "reason", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_stock_movements_on_kind"
    t.index ["occurred_at"], name: "index_stock_movements_on_occurred_at"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.check_constraint "kind::text = ANY (ARRAY['in'::character varying::text, 'out'::character varying::text, 'adjustment'::character varying::text])", name: "stock_movements_kind_check"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "brand", null: false
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "kind", null: false
    t.string "model", null: false
    t.string "plate", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["customer_id"], name: "index_vehicles_on_customer_id"
    t.index ["kind"], name: "index_vehicles_on_kind"
    t.index ["plate"], name: "index_vehicles_on_plate", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['car'::character varying::text, 'suv'::character varying::text, 'pickup'::character varying::text, 'motorcycle'::character varying::text, 'van'::character varying::text])", name: "vehicles_kind_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointment_photos", "appointments"
  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "employees"
  add_foreign_key "appointments", "service_types"
  add_foreign_key "appointments", "vehicles"
  add_foreign_key "chats", "models"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "payments", "appointments"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "vehicles", "customers"
end
