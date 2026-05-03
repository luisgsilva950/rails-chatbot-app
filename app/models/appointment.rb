class Appointment < ApplicationRecord
  STATUSES = %w[scheduled in_progress completed canceled no_show].freeze

  belongs_to :customer
  belongs_to :vehicle
  belongs_to :service_type
  belongs_to :employee, optional: true

  has_many :appointment_photos, dependent: :destroy
  has_many :payments,           dependent: :destroy

  enum :status, STATUSES.index_with(&:itself), default: "scheduled"

  validates :scheduled_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :total_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :upcoming, -> { where(status: %w[scheduled in_progress]).order(:scheduled_at) }
  scope :on_date,  ->(date) { where(scheduled_at: date.all_day) }
  scope :completed_between, ->(range) { completed.where(scheduled_at: range) }
end
