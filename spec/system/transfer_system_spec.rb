RSpec.describe "Transfer management", type: :system do
  before do
    sign_in(@user)
  end
  let!(:url_prefix) { "/#{@organization.to_param}" }
  let(:item) { create(:item) }

  def create_transfer(amount, from_name, to_name)
    visit url_prefix + "/transfers"
    click_link "New Transfer"
    within "form#new_transfer" do
      select from_name, from: "From storage location"
      select to_name, from: "To storage location"
      fill_in "Comment", with: "something"
      select item.name, from: "transfer_line_items_attributes_0_item_id"
      fill_in "transfer_line_items_attributes_0_quantity", with: amount
      click_on "Save"
    end
  end

  it "Does not include inactive items in the line item fields" do
    storage_location = create(:storage_location, :with_items, item: item, item_quantity: 10, name: "From me", organization: @organization)
    item = Item.alphabetized.first

    visit url_prefix + "/transfers/new"

    select storage_location.name, from: "From storage location"
    expect(page).to have_content(item.name)
    select item.name, from: "transfer_line_items_attributes_0_item_id"

    item.update(active: false)

    page.refresh
    within "#new_transfer" do
      select storage_location.name, from: "From storage location"
      expect(page).not_to have_content(item.name)
    end
  end

  it "can transfer an inventory from a storage location to another as a user" do
    from_storage_location = create(:storage_location, :with_items, item: item, name: "From me", organization: @organization)
    to_storage_location = create(:storage_location, :with_items, name: "To me", organization: @organization)
    create_transfer("10", from_storage_location.name, to_storage_location.name)
    expect(page).to have_content("10 items have been transferred")
  end

  context "when there's insufficient inventory at the origin to cover the move" do
    let!(:from_storage_location) { create(:storage_location, :with_items, item: item, item_quantity: 10, name: "From me", organization: @organization) }
    let!(:to_storage_location) { create(:storage_location, :with_items, name: "To me", organization: @organization) }

    scenario "User can transfer an inventory from a storage location to another" do
      create_transfer("100", from_storage_location.name, to_storage_location.name)
      expect(page).to have_content("exceed the available inventory")
    end
  end

  it "can filter the #index by storage location both from and to as a user" do
    from_storage_location = create(:storage_location, name: "here", organization: @organization)
    to_storage_location = create(:storage_location, name: "there", organization: @organization)
    create(:transfer, organization: @organization, from: from_storage_location, to: to_storage_location)
    create(:transfer, organization: @organization, from: to_storage_location, to: from_storage_location)

    visit url_prefix + "/transfers"
    select to_storage_location.name, from: "filters_to_location"
    click_button "Filter"

    expect(page).to have_css("table tr", count: 2)

    visit url_prefix + "/transfers"
    select from_storage_location.name, from: "filters_from_location"
    click_button "Filter"

    expect(page).to have_css("table tr", count: 2)
  end

  it "filters by date" do
    from_storage_location_one = create(:storage_location, name: "here", organization: @organization)
    to_storage_location_one = create(:storage_location, name: "there", organization: @organization)
    create(:transfer, organization: @organization, from: from_storage_location_one, to: to_storage_location_one, created_at: Date.new(2018, 3, 1))
    create(:transfer, organization: @organization, from: to_storage_location_one, to: from_storage_location_one, created_at: Date.new(2018, 2, 1))
    from_storage_location_two = create(:storage_location, :with_items, item: item, name: "From me", organization: @organization)
    to_storage_location_two = create(:storage_location, :with_items, name: "To me", organization: @organization)
    create(:transfer, organization: @organization, from: from_storage_location_two, to: to_storage_location_two, created_at: Date.new(2018, 3, 1))
    create(:transfer, organization: @organization, from: to_storage_location_two, to: from_storage_location_two, created_at: Date.new(2018, 1, 1))
    
    visit url_prefix + "/transfers"

    fill_in "dates_date_from", with: "02/01/2018"
    click_button "Filter"
    expect(page).to have_css("table tbody tr", count: 3)

    fill_in "dates_date_from", with: "03/01/2018"
    click_button "Filter"
    expect(page).to have_css("table tbody tr", count: 2)

    fill_in "dates_date_to", with: "03/01/2018"
    click_button "Filter"
    expect(page).to have_css("table tbody tr", count: 2)

    fill_in "dates_date_to", with: "02/28/2018"
    click_button "Filter"
    expect(page).to have_css("table tbody tr", count: 0)
  end
end
