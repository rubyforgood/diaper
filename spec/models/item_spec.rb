# == Schema Information
#
# Table name: items
#
#  id            :integer          not null, primary key
#  name          :string
#  category      :string
#  created_at    :datetime
#  updated_at    :datetime
#  barcode_count :integer
#

RSpec.describe Item, type: :model do
  context "Validations >" do
    it "requires a unique name" do
      item = create(:item)
      expect(build(:item, name: nil)).not_to be_valid
      expect(build(:item, name: item.name)).not_to be_valid
    end
  end

  context "Filtering >" do
    it "can filter" do
      expect(subject.class).to respond_to :filter
    end

    it "->in_category returns all items in the provided category" do
      create(:item, category: "same")
      create(:item, category: "not same")
      expect(Item.in_category('same').length).to eq(1)
    end

    it "->in_same_category_as returns all items in the same category other than the provided item" do
      item = create(:item, name: "Foo", category: "same")
      other = create(:item, name: "Bar", category: "same")
      create(:item, category: "not same")
      result = Item.in_same_category_as(item)
      expect(result.length).to eq(1)
      expect(result.first).to eq(other)
    end
  end

  context "Methods >" do
    describe "categories" do
      it "returns a list of all categories, unique" do
        item = create(:item, category: "same")
        create(:item, category: "different")
        result = Item.categories
        expect(result.length).to eq(2)
      end
    end

    describe "storage_locations_containing" do
      it "retrieves all storage locations that contain an item" do
        item = create(:item)
        storage_location = create(:storage_location, :with_items, item: item, item_quantity: 10)
        create(:storage_location)
        expect(Item.storage_locations_containing(item).first).to eq(storage_location)
      end
    end

    describe "barcodes_for" do
      it "retrieves all BarcodeItems associated with an item" do
        item = create(:item)
        barcode_item = create(:barcode_item, item: item)
        create(:barcode_item)
        expect(Item.barcodes_for(item).first).to eq(barcode_item)
      end
    end
  end
end
