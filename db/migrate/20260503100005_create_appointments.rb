class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments do |t|
      t.references :customer,     null: false, foreign_key: true
      t.references :vehicle,      null: false, foreign_key: true
      t.references :service_type, null: false, foreign_key: true
      t.references :employee,     foreign_key: true
      t.datetime :scheduled_at, null: false
      t.string   :status,       null: false, default: "scheduled"
      t.integer  :total_cents,  null: false
      t.text     :notes
      t.timestamps
    end

    add_index :appointments, :scheduled_at
    add_index :appointments, :status
    add_index :appointments, [ :scheduled_at, :status ]

    add_check_constraint :appointments,
      "status IN ('scheduled','in_progress','completed','canceled','no_show')",
      name: "appointments_status_check"
  end
end
