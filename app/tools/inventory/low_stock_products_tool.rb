class Inventory::LowStockProductsTool < RubyLLM::Tool
  description "Lists products whose current stock is at or below the configured minimum."

  params do
    string :category, required: false,
           enum: Product::CATEGORIES,
           description: "Filter by category (shampoo, wax, sealant, polish, interior, tool, consumable)."
  end

  def execute(category: nil)
    scope = Product.low_stock
    scope = scope.where(category: category) if category.present?
    scope.order(:stock_quantity).map do |product|
      {
        sku:            product.sku,
        name:           product.name,
        category:       product.category,
        unit:           product.unit,
        stock_quantity: product.stock_quantity,
        min_stock:      product.min_stock
      }
    end
  end
end
