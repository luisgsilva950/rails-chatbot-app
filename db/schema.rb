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

ActiveRecord::Schema[8.1].define(version: 2026_05_03_100009) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "appointment_photos", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.string "caption"
    t.datetime "created_at", null: false
    t.string "stage", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["appointment_id"], name: "index_appointment_photos_on_appointment_id"
    t.index ["stage"], name: "index_appointment_photos_on_stage"
    t.check_constraint "stage::text = ANY (ARRAY['before'::character varying, 'during'::character varying, 'after'::character varying]::text[])", name: "appointment_photos_stage_check"
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
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'canceled'::character varying, 'no_show'::character varying]::text[])", name: "appointments_status_check"
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
    t.check_constraint "role::text = ANY (ARRAY['washer'::character varying, 'detailer'::character varying, 'manager'::character varying]::text[])", name: "employees_role_check"
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
    t.check_constraint "payment_method::text = ANY (ARRAY['cash'::character varying, 'debit'::character varying, 'credit'::character varying, 'pix'::character varying]::text[])", name: "payments_payment_method_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'paid'::character varying, 'refunded'::character varying, 'canceled'::character varying]::text[])", name: "payments_status_check"
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
    t.check_constraint "category::text = ANY (ARRAY['shampoo'::character varying, 'wax'::character varying, 'sealant'::character varying, 'polish'::character varying, 'interior'::character varying, 'tool'::character varying, 'consumable'::character varying]::text[])", name: "products_category_check"
    t.check_constraint "unit::text = ANY (ARRAY['ml'::character varying, 'l'::character varying, 'un'::character varying, 'kg'::character varying]::text[])", name: "products_unit_check"
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
    t.check_constraint "category::text = ANY (ARRAY['wash'::character varying, 'detailing'::character varying, 'protection'::character varying, 'interior'::character varying]::text[])", name: "service_types_category_check"
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
    t.check_constraint "kind::text = ANY (ARRAY['in'::character varying, 'out'::character varying, 'adjustment'::character varying]::text[])", name: "stock_movements_kind_check"
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
    t.check_constraint "kind::text = ANY (ARRAY['car'::character varying, 'suv'::character varying, 'pickup'::character varying, 'motorcycle'::character varying, 'van'::character varying]::text[])", name: "vehicles_kind_check"
  end

  add_foreign_key "appointment_photos", "appointments"
  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "employees"
  add_foreign_key "appointments", "service_types"
  add_foreign_key "appointments", "vehicles"
  add_foreign_key "payments", "appointments"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "vehicles", "customers"
end
