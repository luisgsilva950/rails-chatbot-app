class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :appointment, null: false, foreign_key: true
      t.string   :payment_method, null: false
      t.string   :status,         null: false, default: "pending"
      t.integer  :amount_cents,   null: false
      t.datetime :paid_at
      t.timestamps
    end

    add_index :payments, :payment_method
    add_index :payments, :status
    add_index :payments, :paid_at

    add_check_constraint :payments,
      "payment_method IN ('cash','debit','credit','pix')",
      name: "payments_payment_method_check"

    add_check_constraint :payments,
      "status IN ('pending','paid','refunded','canceled')",
      name: "payments_status_check"
  end
end
