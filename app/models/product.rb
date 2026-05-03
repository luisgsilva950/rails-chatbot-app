class Product < ApplicationRecord
  CATEGORIES = %w[shampoo wax sealant polish interior tool consumable].freeze
  UNITS      = %w[ml l un kg].freeze

  has_many :stock_movements, dependent: :destroy

  enum :category, CATEGORIES.index_with(&:itself)
  enum :unit,     UNITS.index_with(&:itself)

  validates :name, :sku, presence: true
  validates :sku,  uniqueness: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :unit,     presence: true, inclusion: { in: UNITS }
  validates :stock_quantity, :min_stock, :cost_cents, :price_cents,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :low_stock, -> { where("stock_quantity <= min_stock") }
end
