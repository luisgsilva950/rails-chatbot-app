require "rails_helper"

# Forces evaluation of every Tool's `params do ... end` DSL block.
# ruby_llm only evaluates the block lazily when building the JSON schema
# for the LLM API; calling `#params_schema` on an instance runs that path
# and brings the DSL lines under coverage.
RSpec.describe "Tool params schemas" do
  tool_classes = [
    Scheduling::ListAppointmentsForDateTool,
    Scheduling::UpcomingAppointmentsTool,
    Inventory::LowStockProductsTool,
    Inventory::ProductLookupTool,
    Inventory::ProductsConsumedOnDatesTool,
    Inventory::AskAgentTool,
    CashFlow::DailyRevenueTool,
    CashFlow::SalesDaysTool,
    CustomerLookup::FindCustomerByPhoneTool,
    Weather::ForecastTool,
    Weather::AskAgentTool,
    Ui::SuggestChoicesTool
  ]

  tool_classes.each do |klass|
    it "#{klass.name} exposes a JSON schema with properties" do
      schema = klass.new.params_schema

      expect(schema).to be_a(Hash)
      expect(schema["type"]).to eq("object")
      expect(schema["properties"]).to be_a(Hash).and(be_present)
    end
  end
end
