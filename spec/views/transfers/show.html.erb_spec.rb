

RSpec.describe "transfers/show.html.erb", type: :view do
  before(:each) do
    @item = create(:item)
    @item2 = create(:item)
    @to = create(:storage_location, :with_items, name: "Foo", item: @item, item_quantity: 10)
    @from = create(:storage_location, name: "Bar")

    @transfer = create(:transfer, from: @from, to: @to)
    @transfer.line_items << create(:line_item, item: @item, quantity: 10)

    assign(:transfer, @transfer)
    assign(:total, @transfer.total_quantity)
    assign(:line_items, @transfer.sorted_line_items)

    render
  end

  it "lists the names of each storage location in the header" do
    expect(rendered).to have_content(@from.name)
    expect(rendered).to have_content(@to.name)
  end

  it "shows a table with the contents of the transfer and a total at the bottom" do
    expect(rendered).to have_xpath("//table[@id='manifest']/tbody/tr/td", text: @item.name)
    expect(rendered).to have_xpath("//table[@id='manifest']/tbody/tr/td", text: "10")
    expect(rendered).to have_xpath("//table[@id='manifest']/tfoot/tr/td", text: "10")
  end
end
