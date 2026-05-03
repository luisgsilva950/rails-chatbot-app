class Employee < ApplicationRecord
  ROLES = %w[washer detailer manager].freeze

  has_many :appointments, dependent: :nullify

  enum :role, ROLES.index_with(&:itself)

  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }

  scope :active, -> { where(active: true) }
end
