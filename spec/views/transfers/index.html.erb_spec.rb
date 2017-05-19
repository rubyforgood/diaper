

RSpec.describe "transfers/index.html.erb", type: :view do
  before(:each) do
    t1 = create(:transfer, comment: "MOVES STUFF", from: create(:storage_location, name: "From1"), to: create(:storage_location, name: "To1"))
    t1.line_items << create(:line_item, quantity: 10)
    t1.line_items << create(:line_item, quantity: 20)

    t2 = create(:transfer)
    t2.line_items << create(:line_item)

    assign(:transfers, Transfer.all)

    render
  end

  it "shows a table with all the transfers" do
    expect(rendered).to have_xpath("//table[@id='transfers']/tbody/tr", count: 2)
  end

  it "shows the storage location names, total moved, and the comment" do
    expect(rendered).to have_xpath("//table[@id='transfers']/tbody/tr/td", text: "From1")
    expect(rendered).to have_xpath("//table[@id='transfers']/tbody/tr/td", text: "To1")
    expect(rendered).to have_xpath("//table[@id='transfers']/tbody/tr/td", text: "30")
    expect(rendered).to have_xpath("//table[@id='transfers']/tbody/tr/td", text: "MOVES STUFF")
  end
end
