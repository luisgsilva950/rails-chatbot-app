class CreateVehicles < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicles do |t|
      t.references :customer, null: false, foreign_key: true
      t.string  :plate, null: false
      t.string  :brand, null: false
      t.string  :model, null: false
      t.integer :year,  null: false
      t.string  :color, null: false
      t.string  :kind,  null: false
      t.timestamps
    end

    add_index :vehicles, :plate, unique: true
    add_index :vehicles, :kind

    add_check_constraint :vehicles,
      "kind IN ('car','suv','pickup','motorcycle','van')",
      name: "vehicles_kind_check"
  end
end
