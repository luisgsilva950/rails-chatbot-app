class CreateStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_movements do |t|
      t.references :product, null: false, foreign_key: true
      t.string   :kind,        null: false
      t.integer  :quantity,    null: false
      t.string   :reason,      null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :stock_movements, :kind
    add_index :stock_movements, :occurred_at

    add_check_constraint :stock_movements,
      "kind IN ('in','out','adjustment')",
      name: "stock_movements_kind_check"
  end
end
