class ServiceType < ApplicationRecord
  CATEGORIES = %w[wash detailing protection interior].freeze

  has_many :appointments, dependent: :restrict_with_error

  enum :category, CATEGORIES.index_with(&:itself)

  validates :name, presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :price_cents,      presence: true, numericality: { greater_than: 0 }
end
