class Payment < ApplicationRecord
  PAYMENT_METHODS = %w[cash debit credit pix].freeze
  STATUSES        = %w[pending paid refunded canceled].freeze

  belongs_to :appointment

  enum :payment_method, PAYMENT_METHODS.index_with(&:itself)
  enum :status,         STATUSES.index_with(&:itself), default: "pending"

  validates :payment_method, presence: true, inclusion: { in: PAYMENT_METHODS }
  validates :status,         presence: true, inclusion: { in: STATUSES }
  validates :amount_cents,   presence: true, numericality: { greater_than: 0 }

  scope :paid_between, ->(range) { paid.where(paid_at: range) }
end
