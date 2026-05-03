class Customer < ApplicationRecord
  has_many :vehicles,     dependent: :destroy
  has_many :appointments, dependent: :destroy

  validates :name,  presence: true
  validates :phone, presence: true
  validates :email, uniqueness: { case_sensitive: false }, allow_nil: true
  validates :document, uniqueness: true, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
end
