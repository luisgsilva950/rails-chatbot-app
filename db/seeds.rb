# frozen_string_literal: true

# Seeds para a estética automotiva. Idempotente: pode rodar múltiplas vezes.
# Limpa as tabelas antes de popular para evitar duplicatas.

require "securerandom"

puts "Limpando dados existentes..."
[ Payment, StockMovement, AppointmentPhoto, Appointment,
  Vehicle, Customer, Product, ServiceType, Employee ].each(&:delete_all)

RNG = Random.new(20260503)

# ---------------------------------------------------------------------------
# Funcionários
# ---------------------------------------------------------------------------
puts "Criando funcionários..."

EMPLOYEES = [
  { name: "Carlos Henrique Moreira", role: "manager"  },
  { name: "Rafael Almeida Souza",    role: "detailer" },
  { name: "Bruno Silveira Costa",    role: "detailer" },
  { name: "Diego Ramos Ferreira",    role: "washer"   },
  { name: "Lucas Pereira Lima",      role: "washer"   },
  { name: "Anderson Vieira Rocha",   role: "washer"   }
].freeze

EMPLOYEES.each { |attrs| Employee.create!(attrs) }
employees = Employee.all.to_a

# ---------------------------------------------------------------------------
# Catálogo de serviços
# ---------------------------------------------------------------------------
puts "Criando catálogo de serviços..."

SERVICE_TYPES = [
  { name: "Lavagem Simples",           category: "wash",       duration_minutes:  40, price_cents:  4_500,
    description: "Lavagem externa com shampoo neutro, secagem e finalização de pneus." },
  { name: "Lavagem Completa",          category: "wash",       duration_minutes:  75, price_cents:  8_900,
    description: "Lavagem externa, aspiração, limpeza de painel e vidros." },
  { name: "Lavagem a Seco",            category: "wash",       duration_minutes:  60, price_cents:  7_900,
    description: "Lavagem ecológica sem uso de água, ideal para apartamentos." },
  { name: "Lavagem de Motor",          category: "wash",       duration_minutes:  45, price_cents:  9_900,
    description: "Desengraxante específico, proteção de partes elétricas e finalização." },
  { name: "Polimento Comercial",       category: "detailing",  duration_minutes: 180, price_cents: 35_000,
    description: "Remoção de oxidação leve e marcas superficiais. Brilho imediato." },
  { name: "Polimento Técnico",         category: "detailing",  duration_minutes: 360, price_cents: 75_000,
    description: "Correção de pintura em duas etapas, remoção de hologramas e riscos profundos." },
  { name: "Vitrificação de Pintura",   category: "protection", duration_minutes: 480, price_cents: 180_000,
    description: "Aplicação de vidro líquido com proteção de até 24 meses contra UV e contaminantes." },
  { name: "Cristalização",             category: "protection", duration_minutes: 120, price_cents: 22_000,
    description: "Selante de pintura com proteção e brilho por até 3 meses." },
  { name: "Descontaminação Ferrosa",   category: "protection", duration_minutes:  90, price_cents: 15_000,
    description: "Remoção de pó de freio e contaminação metálica antes de polimento." },
  { name: "Higienização Interna",      category: "interior",   duration_minutes: 240, price_cents: 45_000,
    description: "Limpeza profunda de bancos, tetos e carpetes. Remoção de odores." },
  { name: "Hidratação de Couro",       category: "interior",   duration_minutes:  90, price_cents: 18_000,
    description: "Limpeza, hidratação e proteção de bancos e revestimentos em couro." },
  { name: "Impermeabilização de Tecido", category: "interior", duration_minutes: 120, price_cents: 25_000,
    description: "Aplicação de impermeabilizante em bancos de tecido contra líquidos e manchas." }
].freeze

SERVICE_TYPES.each { |attrs| ServiceType.create!(attrs) }
service_types = ServiceType.all.to_a

# ---------------------------------------------------------------------------
# Clientes
# ---------------------------------------------------------------------------
puts "Criando clientes..."

FIRST_NAMES = %w[
  Lucas Pedro João Gabriel Mateus Felipe Rafael Bruno Thiago Diego
  Mariana Beatriz Camila Juliana Larissa Amanda Patrícia Fernanda Carolina Vanessa
  André Rodrigo Eduardo Marcelo Ricardo Roberto Henrique Daniel Vinícius Leonardo
  Ana Letícia Bianca Aline Renata Cláudia Helena Sofia Isabela Gabriela
].freeze

LAST_NAMES = %w[
  Silva Santos Oliveira Souza Pereira Lima Costa Rodrigues Almeida Carvalho
  Gomes Martins Araújo Ribeiro Barbosa Cardoso Castro Dias Ferreira Fernandes
  Mendes Moreira Nunes Peixoto Ramos Rocha Teixeira Vieira Cavalcanti Pinto
].freeze

def fake_phone
  "(#{[ 11, 21, 31, 41, 51, 61, 71, 81 ].sample(random: RNG)}) 9#{rand(1000..9999)}-#{rand(1000..9999)}"
end

def fake_cpf(index)
  base = format("%011d", 11_111_111_111 + index * 9_876_543)
  "#{base[0, 3]}.#{base[3, 3]}.#{base[6, 3]}-#{base[9, 2]}"
end

30.times do |i|
  first = FIRST_NAMES.sample(random: RNG)
  last1 = LAST_NAMES.sample(random: RNG)
  last2 = LAST_NAMES.sample(random: RNG)
  name  = "#{first} #{last1} #{last2}"

  Customer.create!(
    name:     name,
    phone:    fake_phone,
    email:    "#{first.downcase}.#{last1.downcase}#{i}@example.com",
    document: fake_cpf(i),
    notes:    [ nil, "Cliente VIP", "Prefere atendimento aos sábados", "Cliente desde 2023" ].sample(random: RNG)
  )
end

customers = Customer.all.to_a

# ---------------------------------------------------------------------------
# Veículos
# ---------------------------------------------------------------------------
puts "Criando veículos..."

VEHICLE_CATALOG = [
  { brand: "Volkswagen", model: "Gol",       kind: "car"        },
  { brand: "Volkswagen", model: "Polo",      kind: "car"        },
  { brand: "Volkswagen", model: "T-Cross",   kind: "suv"        },
  { brand: "Volkswagen", model: "Saveiro",   kind: "pickup"     },
  { brand: "Fiat",       model: "Argo",      kind: "car"        },
  { brand: "Fiat",       model: "Pulse",     kind: "suv"        },
  { brand: "Fiat",       model: "Strada",    kind: "pickup"     },
  { brand: "Fiat",       model: "Toro",      kind: "pickup"     },
  { brand: "Chevrolet",  model: "Onix",      kind: "car"        },
  { brand: "Chevrolet",  model: "Tracker",   kind: "suv"        },
  { brand: "Chevrolet",  model: "S10",       kind: "pickup"     },
  { brand: "Hyundai",    model: "HB20",      kind: "car"        },
  { brand: "Hyundai",    model: "Creta",     kind: "suv"        },
  { brand: "Toyota",     model: "Corolla",   kind: "car"        },
  { brand: "Toyota",     model: "Hilux",     kind: "pickup"     },
  { brand: "Toyota",     model: "Yaris",     kind: "car"        },
  { brand: "Honda",      model: "Civic",     kind: "car"        },
  { brand: "Honda",      model: "HR-V",      kind: "suv"        },
  { brand: "Honda",      model: "CG 160",    kind: "motorcycle" },
  { brand: "Yamaha",     model: "Fazer 250", kind: "motorcycle" },
  { brand: "Renault",    model: "Kwid",      kind: "car"        },
  { brand: "Renault",    model: "Duster",    kind: "suv"        },
  { brand: "Jeep",       model: "Renegade",  kind: "suv"        },
  { brand: "Jeep",       model: "Compass",   kind: "suv"        },
  { brand: "Nissan",     model: "Kicks",     kind: "suv"        },
  { brand: "Ford",       model: "Ranger",    kind: "pickup"     },
  { brand: "Mercedes",   model: "Sprinter",  kind: "van"        },
  { brand: "Iveco",      model: "Daily",     kind: "van"        }
].freeze

COLORS = %w[Preto Branco Prata Cinza Vermelho Azul Verde Bege Marrom].freeze

def fake_plate(index)
  letters = ("A".."Z").to_a
  l1 = letters.sample(random: RNG)
  l2 = letters.sample(random: RNG)
  l3 = letters.sample(random: RNG)
  digit_letter = letters.sample(random: RNG)
  "#{l1}#{l2}#{l3}#{(index % 10)}#{digit_letter}#{format('%02d', index % 100)}"
end

vehicle_index = 0
customers.each do |customer|
  count = [ 1, 1, 1, 2, 2, 3 ].sample(random: RNG)
  count.times do
    catalog = VEHICLE_CATALOG.sample(random: RNG)
    Vehicle.create!(
      customer: customer,
      plate:    fake_plate(vehicle_index),
      brand:    catalog[:brand],
      model:    catalog[:model],
      kind:     catalog[:kind],
      year:     rand(2010..2025),
      color:    COLORS.sample(random: RNG)
    )
    vehicle_index += 1
  end
end

vehicles = Vehicle.includes(:customer).to_a

# ---------------------------------------------------------------------------
# Agendamentos
# ---------------------------------------------------------------------------
puts "Criando agendamentos..."

today = Time.zone.today
business_hours = (8..17).to_a

def random_business_time(date)
  hour   = (8..17).to_a.sample(random: RNG)
  minute = [ 0, 15, 30, 45 ].sample(random: RNG)
  Time.zone.local(date.year, date.month, date.day, hour, minute)
end

# Agendamentos passados (60 dias atrás até ontem) — completed/canceled/no_show
puts "  -> passados..."
130.times do
  days_ago = rand(1..60)
  date     = today - days_ago
  next if date.sunday?

  vehicle      = vehicles.sample(random: RNG)
  service_type = service_types.sample(random: RNG)
  status       = [ "completed" ] * 8 + [ "canceled" ] + [ "no_show" ]

  Appointment.create!(
    customer:     vehicle.customer,
    vehicle:      vehicle,
    service_type: service_type,
    employee:     employees.sample(random: RNG),
    scheduled_at: random_business_time(date),
    status:       status.sample(random: RNG),
    total_cents:  service_type.price_cents,
    notes:        nil
  )
end

# Agendamentos de hoje
puts "  -> hoje..."
8.times do |i|
  vehicle      = vehicles.sample(random: RNG)
  service_type = service_types.sample(random: RNG)
  hour         = business_hours[i % business_hours.size]
  scheduled_at = Time.zone.local(today.year, today.month, today.day, hour, [ 0, 30 ].sample(random: RNG))
  status       = scheduled_at < Time.current ? %w[completed in_progress].sample(random: RNG) : "scheduled"

  Appointment.create!(
    customer:     vehicle.customer,
    vehicle:      vehicle,
    service_type: service_type,
    employee:     employees.sample(random: RNG),
    scheduled_at: scheduled_at,
    status:       status,
    total_cents:  service_type.price_cents,
    notes:        [ nil, "Cliente vai aguardar no local", "Buscar e devolver" ].sample(random: RNG)
  )
end

# Agendamentos futuros (próximos 14 dias)
puts "  -> futuros..."
60.times do
  days_ahead = rand(1..14)
  date       = today + days_ahead
  next if date.sunday?

  vehicle      = vehicles.sample(random: RNG)
  service_type = service_types.sample(random: RNG)

  Appointment.create!(
    customer:     vehicle.customer,
    vehicle:      vehicle,
    service_type: service_type,
    employee:     employees.sample(random: RNG),
    scheduled_at: random_business_time(date),
    status:       "scheduled",
    total_cents:  service_type.price_cents,
    notes:        nil
  )
end

appointments = Appointment.includes(:service_type).to_a

# ---------------------------------------------------------------------------
# Fotos dos agendamentos
# ---------------------------------------------------------------------------
puts "Criando fotos..."

completed = appointments.select { |a| a.status == "completed" }
completed.sample(80, random: RNG).each do |appt|
  %w[before after].each do |stage|
    AppointmentPhoto.create!(
      appointment: appt,
      url:         "https://placehold.co/800x600/png?text=#{stage}-#{appt.id}",
      stage:       stage,
      caption:     stage == "before" ? "Antes do serviço" : "Após finalização"
    )
  end
end

# ---------------------------------------------------------------------------
# Pagamentos
# ---------------------------------------------------------------------------
puts "Criando pagamentos..."

PAYMENT_METHODS = %w[cash debit credit pix pix pix].freeze # pix com peso maior

(appointments.select { |a| %w[completed in_progress].include?(a.status) }).each do |appt|
  paid_at = appt.scheduled_at + rand(15..120).minutes
  Payment.create!(
    appointment:    appt,
    payment_method: PAYMENT_METHODS.sample(random: RNG),
    status:         "paid",
    amount_cents:   appt.total_cents,
    paid_at:        paid_at
  )
end

# ---------------------------------------------------------------------------
# Produtos
# ---------------------------------------------------------------------------
puts "Criando produtos..."

PRODUCTS = [
  { name: "Shampoo Neutro Auto Brilho 5L",       sku: "SH-001", category: "shampoo",    unit: "l",  stock_quantity: 24, min_stock: 5,  cost_cents:  4_500, price_cents:  8_900 },
  { name: "Shampoo Desengraxante 5L",            sku: "SH-002", category: "shampoo",    unit: "l",  stock_quantity:  3, min_stock: 5,  cost_cents:  6_500, price_cents: 11_900 },
  { name: "Shampoo Automotivo Concentrado 1L",   sku: "SH-003", category: "shampoo",    unit: "l",  stock_quantity: 40, min_stock: 8,  cost_cents:  2_900, price_cents:  5_500 },
  { name: "Cera de Carnaúba 300g",               sku: "WX-001", category: "wax",        unit: "un", stock_quantity: 12, min_stock: 4,  cost_cents:  3_500, price_cents:  6_900 },
  { name: "Cera Sintética Cleaner 300g",         sku: "WX-002", category: "wax",        unit: "un", stock_quantity:  2, min_stock: 4,  cost_cents:  4_200, price_cents:  7_900 },
  { name: "Cera Líquida 500ml",                  sku: "WX-003", category: "wax",        unit: "ml", stock_quantity: 18, min_stock: 5,  cost_cents:  3_900, price_cents:  7_500 },
  { name: "Vitrificador Cerâmico 50ml",          sku: "SE-001", category: "sealant",    unit: "ml", stock_quantity:  6, min_stock: 2,  cost_cents: 28_000, price_cents: 55_000 },
  { name: "Selante Sintético 500ml",             sku: "SE-002", category: "sealant",    unit: "ml", stock_quantity:  9, min_stock: 3,  cost_cents:  9_500, price_cents: 18_900 },
  { name: "Cristalizador 500ml",                 sku: "SE-003", category: "sealant",    unit: "ml", stock_quantity: 14, min_stock: 4,  cost_cents:  6_800, price_cents: 13_500 },
  { name: "Composto Polidor Refino 1L",          sku: "PL-001", category: "polish",     unit: "l",  stock_quantity:  8, min_stock: 3,  cost_cents: 12_000, price_cents: 22_000 },
  { name: "Lustrador Polidor 1L",                sku: "PL-002", category: "polish",     unit: "l",  stock_quantity:  4, min_stock: 3,  cost_cents: 11_000, price_cents: 19_900 },
  { name: "Massa de Polir Corte 1L",             sku: "PL-003", category: "polish",     unit: "l",  stock_quantity:  1, min_stock: 3,  cost_cents: 13_500, price_cents: 24_900 },
  { name: "Limpa Estofado 500ml",                sku: "IN-001", category: "interior",   unit: "ml", stock_quantity: 20, min_stock: 6,  cost_cents:  2_400, price_cents:  4_800 },
  { name: "Hidratante de Couro 500ml",           sku: "IN-002", category: "interior",   unit: "ml", stock_quantity: 11, min_stock: 4,  cost_cents:  4_900, price_cents:  9_500 },
  { name: "Impermeabilizante de Tecido 500ml",   sku: "IN-003", category: "interior",   unit: "ml", stock_quantity:  7, min_stock: 3,  cost_cents:  6_200, price_cents: 12_900 },
  { name: "APC - Limpador Multiuso 5L",          sku: "IN-004", category: "interior",   unit: "l",  stock_quantity: 16, min_stock: 5,  cost_cents:  4_500, price_cents:  9_500 },
  { name: "Pretinho de Pneu 500ml",              sku: "IN-005", category: "interior",   unit: "ml", stock_quantity: 28, min_stock: 8,  cost_cents:  1_900, price_cents:  3_900 },
  { name: "Boina de Espuma Corte",               sku: "TL-001", category: "tool",       unit: "un", stock_quantity: 10, min_stock: 4,  cost_cents:  4_500, price_cents:  8_900 },
  { name: "Boina de Lã Polimento",               sku: "TL-002", category: "tool",       unit: "un", stock_quantity:  5, min_stock: 3,  cost_cents:  5_500, price_cents:  9_900 },
  { name: "Microfibra 40x40cm",                  sku: "TL-003", category: "tool",       unit: "un", stock_quantity: 60, min_stock: 20, cost_cents:    900, price_cents:  1_900 },
  { name: "Argila Descontaminante 200g",         sku: "TL-004", category: "tool",       unit: "un", stock_quantity: 14, min_stock: 4,  cost_cents:  3_900, price_cents:  7_500 },
  { name: "Esponja Aplicadora",                  sku: "TL-005", category: "tool",       unit: "un", stock_quantity: 35, min_stock: 10, cost_cents:    400, price_cents:    900 },
  { name: "Luva de Microfibra",                  sku: "CN-001", category: "consumable", unit: "un", stock_quantity: 22, min_stock: 6,  cost_cents:  1_200, price_cents:  2_500 },
  { name: "Saco de Lixo 100L (pacote)",          sku: "CN-002", category: "consumable", unit: "un", stock_quantity: 12, min_stock: 4,  cost_cents:  1_900, price_cents:  3_500 },
  { name: "Detergente Neutro 5L",                sku: "CN-003", category: "consumable", unit: "l",  stock_quantity:  4, min_stock: 5,  cost_cents:  1_500, price_cents:  2_900 }
].freeze

PRODUCTS.each { |attrs| Product.create!(attrs) }
products = Product.all.to_a

# ---------------------------------------------------------------------------
# Movimentações de estoque
# ---------------------------------------------------------------------------
puts "Criando movimentações de estoque..."

IN_REASONS  = [ "Reposição mensal", "Compra fornecedor A", "Compra fornecedor B", "Reposição emergencial" ].freeze
OUT_REASONS = [ "Consumo em serviço", "Polimento agendado", "Higienização interna", "Lavagem completa" ].freeze
ADJ_REASONS = [ "Inventário mensal", "Correção de contagem" ].freeze

products.each do |product|
  # entrada inicial
  StockMovement.create!(
    product:     product,
    kind:        "in",
    quantity:    product.stock_quantity + rand(5..20),
    reason:      IN_REASONS.sample(random: RNG),
    occurred_at: Time.current - rand(20..40).days
  )

  # 2-5 saídas espalhadas
  rand(2..5).times do
    StockMovement.create!(
      product:     product,
      kind:        "out",
      quantity:    rand(1..5),
      reason:      OUT_REASONS.sample(random: RNG),
      occurred_at: Time.current - rand(1..30).days
    )
  end
end

# alguns ajustes
products.sample(5, random: RNG).each do |product|
  StockMovement.create!(
    product:     product,
    kind:        "adjustment",
    quantity:    rand(1..3),
    reason:      ADJ_REASONS.sample(random: RNG),
    occurred_at: Time.current - rand(1..15).days
  )
end

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
puts ""
puts "Seed concluído:"
puts "  Funcionários:       #{Employee.count}"
puts "  Serviços:           #{ServiceType.count}"
puts "  Clientes:           #{Customer.count}"
puts "  Veículos:           #{Vehicle.count}"
puts "  Agendamentos:       #{Appointment.count}"
puts "    -> hoje:          #{Appointment.on_date(today).count}"
puts "    -> futuros:       #{Appointment.where('scheduled_at > ?', Time.current).count}"
puts "    -> completed:     #{Appointment.completed.count}"
puts "  Fotos:              #{AppointmentPhoto.count}"
puts "  Pagamentos:         #{Payment.count} (R$ #{(Payment.paid.sum(:amount_cents) / 100.0)})"
puts "  Produtos:           #{Product.count} (#{Product.low_stock.count} em estoque baixo)"
puts "  Mov. estoque:       #{StockMovement.count}"
