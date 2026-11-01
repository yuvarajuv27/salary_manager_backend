# spec/smoke_spec.rb
RSpec.describe "smoke" do
  it "loads the Rails environment" do
    expect(Rails.application).to be_present
  end
end
