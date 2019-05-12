# == Schema Information
#
# Table name: storage_locations
#
#  id              :integer          not null, primary key
#  name            :string
#  address         :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :integer
#  latitude        :float
#  longitude       :float
#

class StorageLocation < ApplicationRecord
  require "csv"

  belongs_to :organization
  has_many :inventory_items, -> { includes(:item).order("items.name") },
           inverse_of: :storage_location
  has_many :donations, dependent: :destroy
  has_many :distributions, dependent: :destroy
  has_many :items, through: :inventory_items
  has_many :transfers_from, class_name: "Transfer",
                            inverse_of: :from,
                            foreign_key: :id,
                            dependent: :destroy
  has_many :transfers_to, class_name: "Transfer",
                          inverse_of: :to,
                          foreign_key: :id,
                          dependent: :destroy

  validates :name, :address, :organization, presence: true

  include Geocodable
  include Filterable
  scope :containing, ->(item_id) {
    joins(:inventory_items).where("inventory_items.item_id = ?", item_id)
  }
  scope :alphabetized, -> { order(:name) }
  scope :for_csv_export, ->(organization) { where(organization: organization) }

  def self.item_total(item_id)
    StorageLocation.select("quantity")
                   .joins(:inventory_items)
                   .where("inventory_items.item_id = ?", item_id)
                   .collect(&:quantity)
                   .reduce(:+)
  end

  def self.items_inventoried
    Item.joins(:storage_locations).select(:id, :name).group(:id, :name).order(name: :asc)
  end

  def item_total(item_id)
    inventory_items.select(:quantity).find_by(item_id: item_id).try(:quantity)
  end

  def size
    inventory_items.sum(:quantity)
  end

  def to_csv
    org = organization

    CSV.generate(headers: true) do |csv|
      csv << ["Quantity", "DO NOT CHANGE ANYTHING IN THIS ROW"]
      org.items.each do |item|
        csv << ["", item.name]
      end
    end
  end

  # NOTE: Make this code clearer in its intent -- needs more context
  def adjust_from_past!(itemizable, previous_line_item_values)
    itemizable.line_items.each do |line_item|
      # NOTE: Can't we do an association lookup, instead of going all the way up to the model?
      inventory_item = InventoryItem.find_or_create_by(storage_location_id: id, item_id: line_item.item_id)
      # If the item wasn't deleted by the user, then it will be present to be deleted
      # here, and delete returns the item as a return value.
      if previous_line_item_value = previous_line_item_values.delete(line_item.id)
        inventory_item.quantity += line_item.quantity
        inventory_item.quantity -= previous_line_item_value.quantity
        inventory_item.save!
      end
      inventory_item.destroy! if inventory_item.quantity.zero?
    end
    # Update storage for line items that are no longer persisted because they
    # were removed during the update/delete process.
    previous_line_item_values.values.each do |value|
      inventory_item = InventoryItem.find_or_create_by(storage_location_id: id, item_id: value.item_id)
      inventory_item.decrement!(:quantity, value.quantity)
      inventory_item.destroy! if inventory_item.quantity.zero?
    end
  end

  # NOTE: We should generalize this elsewhere -- Importable concern?
  def self.import_csv(csv, organization)
    csv.each do |row|
      loc = StorageLocation.new(row.to_hash)
      loc.organization_id = organization
      loc.save!
    end
  end

  # NOTE: We should generalize this elsewhere -- Importable concern?
  def self.import_inventory(filename, org, loc)
    current_org = Organization.find(org)
    adjustment = current_org.adjustments.create(storage_location_id: loc.to_i, comment: "Starting Inventory")
    # NOTE: this was originally headers: false; it may create buggy behavior
    CSV.parse(filename, headers: true) do |row|
      adjustment.line_items
                .create(quantity: row[0].to_i, item_id: current_org.items.find_by(name: row[1]))
    end
    adjustment.storage_location.increase_inventory(adjustment)
  end

  # FIXME: After this is stable, revisit how we do logging
  def increase_inventory(itemizable_array)
    itemizable_array = itemizable_array.is_a?(Array) ? itemizable_array : itemizable_array.to_a

    # This is, at least for now, how we log changes to the inventory made in this call
    log = {}
    # Iterate through each of the line-items in the moving box
    itemizable_array.each do |item_hash|
      # TODO: make this an aggregate change
      Item.unscoped.find(item_hash[:item_id]).update(active: true)
      # Locate the storage box for the item, or create a new storage box for it
      inventory_item = inventory_items.find_or_create_by!(item_id: item_hash[:item_id])
      # Increase the quantity-on-record for that item
      inventory_item.increment!(:quantity, item_hash[:quantity].to_i)
      # Record in the log that this has occurred
      log[item_hash[:item_id]] = "+#{item_hash[:quantity]}"
    end
    # log could be pulled from dirty AR stuff?
    # Save the final changes -- does this need to occur here?
    save
    # return log
    log
  end

  # TODO: re-evaluate this for optimization
  def decrease_inventory(itemizable_array)
    itemizable_array = itemizable_array.is_a?(Array) ? itemizable_array : itemizable_array.to_a
    # This is, at least for now, how we log changes to the inventory made in this call
    log = {}
    # This tracks items that have insufficient inventory counts to be reduced as much
    insufficient_items = []
    # Iterate through each of the line-items in the moving box
    itemizable_array.each do |item|
      # Locate the storage box for the item, or create an empty storage box
      inventory_item = inventory_items.find_by(item_id: item[:item_id]) || inventory_items.build
      # If we've got sufficient inventory in the storage box to fill the moving box, then continue
      next unless inventory_item.quantity < item[:quantity]

      # Otherwise, we need to record that there was insufficient inventory on-hand
      insufficient_items << {
        item_id: item[:item_id],
        item_name: item[:name],
        quantity_on_hand: inventory_item.quantity,
        quantity_requested: item[:quantity]
      }
    end

    # NOTE: Could this be handled by a validation instead?
    # If we found any insufficiencies
    unless insufficient_items.empty?
      # Raise this custom error with information about each of the items that showed insufficient
      # This bails out of the method!
      raise Errors::InsufficientAllotment.new(
        "Requested items exceed the available inventory",
        insufficient_items
      )
    end

    # Re-run through the items in the moving box again
    itemizable_array.each do |item|
      # Look for the moving box for this item -- we know there is sufficient quantity this time
      # Raise AR:RNF if it fails to find it -- though that seems moot since it would have been
      # captured by the previous block.
      inventory_item = inventory_items.find_by(item_id: item[:item_id])
      # Reduce the inventory box quantity
      inventory_item.decrement!(:quantity, item[:quantity])
      # Record in the log that this has occurred
      log[item[:item_id]] = "-#{item[:quantity]}"
    end
    # log could be pulled from dirty AR stuff
    save!
    # return log
    log
  end

  def self.csv_export_headers
    ["Name", "Address", "Total Inventory"]
  end

  def csv_export_attributes
    [name, address, size]
  end

  private

  def update_inventory_inventory_items(records)
    ActiveRecord::Base.transaction do
      records.each do |inventory_item_id, quantity|
        InventoryItem.find(inventory_item_id).update(quantity: quantity)
      end
    end
  end
end
