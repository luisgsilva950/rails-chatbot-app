class AppointmentPhoto < ApplicationRecord
  STAGES = %w[before during after].freeze

  belongs_to :appointment

  enum :stage, STAGES.index_with(&:itself)

  validates :url,   presence: true
  validates :stage, presence: true, inclusion: { in: STAGES }
end
