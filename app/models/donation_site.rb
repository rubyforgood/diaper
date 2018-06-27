# == Schema Information
#
# Table name: donation_sites
#
#  id              :bigint(8)        not null, primary key
#  name            :string
#  address         :string
#  created_at      :datetime
#  updated_at      :datetime
#  organization_id :integer
#  latitude        :float
#  longitude       :float

class DonationSite < ApplicationRecord
  require "csv"

  belongs_to :organization

  validates :name, :address, :organization, presence: true

  geocoded_by :address
  after_validation :geocode, if: :address_changed?

  has_many :donations

  def self.import_csv(filename, organization)
    CSV.parse(filename, headers: true) do |row|
      loc = DonationSite.new(row.to_hash)
      loc.organization_id = organization
      loc.save!
    end
  end
end
