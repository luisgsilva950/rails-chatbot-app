class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.string  :name,   null: false
      t.string  :role,   null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :employees, :role
    add_index :employees, :active

    add_check_constraint :employees,
      "role IN ('washer','detailer','manager')",
      name: "employees_role_check"
  end
end
