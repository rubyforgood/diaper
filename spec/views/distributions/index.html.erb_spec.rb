RSpec.describe "distributions/index.html.erb", type: :view do
  before :each do
      item = create(:item)
      storage_location = create(:storage_location, :with_items, item_quantity: 10, item: item)
      @distribution = create(:distribution, :with_items, storage_location: storage_location, item_quantity: 10, item: item)

      assign(:distributions, [@distribution])
      render
    end

    it "shows summary information about the distributions, including CRUD controls" do
      # The Partner Name
      expect(rendered).to have_xpath("//table/tbody/tr/td", text: @distribution.partner.name)
      # The source storage location
      expect(rendered).to have_xpath("//table/tbody/tr/td", text: @distribution.storage_location.name)
      # The total quantity of items in this distribution so far
      expect(rendered).to have_xpath("//table/tbody/tr/td", text: "10")
      # The link for viewing the distribution
      expect(rendered).to have_xpath("//table/tbody/tr/td/a[@href='#{distribution_path(@distribution)}']")
      # The link for reclaiming the distribution
      expect(rendered).to have_xpath("//table/tbody/tr/td/a[@href='#{reclaim_distribution_path(@distribution)}']")
      # The link for printing the distribution
      expect(rendered).to have_xpath("//table/tbody/tr/td/a[@href='#{print_distribution_path(@distribution)}']")
    end
end
