# == Schema Information
#
# Table name: items
#
#  id                           :integer          not null, primary key
#  active                       :boolean          default(TRUE)
#  barcode_count                :integer
#  category                     :string
#  distribution_quantity        :integer
#  name                         :string
#  on_hand_minimum_quantity     :integer          default(0), not null
#  on_hand_recommended_quantity :integer
#  package_size                 :integer
#  partner_key                  :string
#  value_in_cents               :integer          default(0)
#  visible_to_partners          :boolean          default(TRUE), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  organization_id              :integer
#
class Kit < Item
  include Itemizable

  belongs_to :organization

  validates :organization, presence: true
end
