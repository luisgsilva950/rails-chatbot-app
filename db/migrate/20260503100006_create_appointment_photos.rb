class CreateAppointmentPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_photos do |t|
      t.references :appointment, null: false, foreign_key: true
      t.string :url,     null: false
      t.string :stage,   null: false
      t.string :caption
      t.timestamps
    end

    add_index :appointment_photos, :stage

    add_check_constraint :appointment_photos,
      "stage IN ('before','during','after')",
      name: "appointment_photos_stage_check"
  end
end
