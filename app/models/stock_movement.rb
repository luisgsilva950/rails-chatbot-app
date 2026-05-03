class StockMovement < ApplicationRecord
  KINDS = %w[in out adjustment].freeze

  belongs_to :product

  enum :kind, KINDS.index_with(&:itself)

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :reason, :occurred_at, presence: true
end
