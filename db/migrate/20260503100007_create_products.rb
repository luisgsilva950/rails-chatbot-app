class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string  :name,           null: false
      t.string  :sku,            null: false
      t.string  :category,       null: false
      t.string  :unit,           null: false
      t.integer :stock_quantity, null: false, default: 0
      t.integer :min_stock,      null: false, default: 0
      t.integer :cost_cents,     null: false
      t.integer :price_cents,    null: false
      t.timestamps
    end

    add_index :products, :sku, unique: true
    add_index :products, :category
    add_index :products, :stock_quantity

    add_check_constraint :products,
      "category IN ('shampoo','wax','sealant','polish','interior','tool','consumable')",
      name: "products_category_check"

    add_check_constraint :products,
      "unit IN ('ml','l','un','kg')",
      name: "products_unit_check"
  end
end
