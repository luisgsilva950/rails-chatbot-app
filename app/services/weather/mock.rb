# Static mock weather data, intentionally correlated with the appointment
# volume seen in the seeded dataset so the chatbot can do meaningful
# weather × sales analysis. Values are illustrative — not real forecasts.
module Weather
  module Mock
    CONDITIONS = %w[sunny partly_cloudy cloudy rain storm].freeze

    DATA = {
      Date.new(2026, 5, 3)  => { condition: "sunny",         temperature_c: 28, precipitation_mm: 0  },
      Date.new(2026, 5, 2)  => { condition: "partly_cloudy", temperature_c: 24, precipitation_mm: 0  },
      Date.new(2026, 5, 1)  => { condition: "cloudy",        temperature_c: 21, precipitation_mm: 1  },
      Date.new(2026, 4, 30) => { condition: "rain",          temperature_c: 18, precipitation_mm: 22 },
      Date.new(2026, 4, 29) => { condition: "sunny",         temperature_c: 27, precipitation_mm: 0  },
      Date.new(2026, 4, 28) => { condition: "partly_cloudy", temperature_c: 23, precipitation_mm: 0  },
      Date.new(2026, 4, 27) => { condition: "sunny",         temperature_c: 26, precipitation_mm: 0  },
      Date.new(2026, 4, 25) => { condition: "rain",          temperature_c: 17, precipitation_mm: 28 },
      Date.new(2026, 4, 22) => { condition: "storm",         temperature_c: 16, precipitation_mm: 42 },
      Date.new(2026, 4, 20) => { condition: "partly_cloudy", temperature_c: 22, precipitation_mm: 0  },
      Date.new(2026, 4, 18) => { condition: "cloudy",        temperature_c: 20, precipitation_mm: 3  },
      Date.new(2026, 4, 17) => { condition: "rain",          temperature_c: 18, precipitation_mm: 19 },
      Date.new(2026, 4, 16) => { condition: "rain",          temperature_c: 17, precipitation_mm: 24 },
      Date.new(2026, 4, 14) => { condition: "sunny",         temperature_c: 29, precipitation_mm: 0  },
      Date.new(2026, 4, 11) => { condition: "cloudy",        temperature_c: 21, precipitation_mm: 2  },
      Date.new(2026, 4, 9)  => { condition: "partly_cloudy", temperature_c: 23, precipitation_mm: 0  },
      Date.new(2026, 4, 8)  => { condition: "rain",          temperature_c: 18, precipitation_mm: 16 },
      Date.new(2026, 4, 7)  => { condition: "cloudy",        temperature_c: 20, precipitation_mm: 1  },
      Date.new(2026, 4, 6)  => { condition: "rain",          temperature_c: 19, precipitation_mm: 21 },
      Date.new(2026, 4, 4)  => { condition: "rain",          temperature_c: 18, precipitation_mm: 14 },
      Date.new(2026, 4, 3)  => { condition: "partly_cloudy", temperature_c: 23, precipitation_mm: 0  }
    }.freeze

    module_function

    # Returns the mocked weather for a single date, or nil if not available.
    def fetch(date)
      DATA[to_date(date)]
    end

    # Returns an array of `{ date:, condition:, temperature_c:, precipitation_mm: }`
    # entries for every mocked day inside the inclusive range, sorted DESC.
    def range(start_date, end_date)
      range = to_date(start_date)..to_date(end_date)
      DATA.select { |date, _| range.cover?(date) }
          .sort_by { |date, _| date }
          .reverse
          .map { |date, attrs| attrs.merge(date: date.iso8601) }
    end

    def to_date(value)
      value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    end
  end
end
