class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :name,       null: false
      t.string :phone,      null: false
      t.string :email
      t.string :document
      t.text   :notes
      t.timestamps
    end

    add_index :customers, :phone
    add_index :customers, :email
    add_index :customers, :document, unique: true, where: "document IS NOT NULL"
  end
end
