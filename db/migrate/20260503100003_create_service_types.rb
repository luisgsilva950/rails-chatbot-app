class CreateServiceTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :service_types do |t|
      t.string  :name,             null: false
      t.string  :category,         null: false
      t.text    :description
      t.integer :duration_minutes, null: false
      t.integer :price_cents,      null: false
      t.timestamps
    end

    add_index :service_types, :name, unique: true
    add_index :service_types, :category

    add_check_constraint :service_types,
      "category IN ('wash','detailing','protection','interior')",
      name: "service_types_category_check"
  end
end
