class Vehicle < ApplicationRecord
  KINDS = %w[car suv pickup motorcycle van].freeze

  belongs_to :customer
  has_many :appointments, dependent: :restrict_with_error

  enum :kind, KINDS.index_with(&:itself)

  validates :plate, presence: true, uniqueness: true
  validates :brand, :model, :color, presence: true
  validates :kind,  presence: true, inclusion: { in: KINDS }
  validates :year,  presence: true, numericality: { greater_than: 1950 }
end
