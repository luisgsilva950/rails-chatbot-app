class Inventory::LowStockProductsTool < RubyLLM::Tool
  description "Lista produtos com estoque atual igual ou abaixo do mínimo."

  params do
    string :category, required: false,
           enum: Product::CATEGORIES,
           description: "Filtra por categoria (shampoo, wax, sealant, polish, interior, tool, consumable)."
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
