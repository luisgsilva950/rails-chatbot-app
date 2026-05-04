class Inventory::ProductLookupTool < RubyLLM::Tool
  description "Searches inventory products by name or SKU. Partial, case-insensitive match."

  params do
    string :query, description: "Search term: part of the product name or SKU."
  end

  def execute(query:)
    term = query.to_s.strip
    return { error: "Provide a search term." } if term.empty?

    Product.where("name ILIKE :q OR sku ILIKE :q", q: "%#{term}%").limit(20).map do |product|
      {
        sku:            product.sku,
        name:           product.name,
        category:       product.category,
        unit:           product.unit,
        stock_quantity: product.stock_quantity,
        price_brl:      product.price_cents / 100.0
      }
    end
  end
end
