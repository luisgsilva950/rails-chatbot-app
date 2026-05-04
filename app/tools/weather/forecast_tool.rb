# Low-level weather lookup. Used by `WeatherAgent` to read the mock.
class Weather::ForecastTool < RubyLLM::Tool
  description "Consulta dados meteorológicos (mockados) para uma data ou intervalo, incluindo datas passadas, presentes e futuras. Retorna condição, temperatura e precipitação por dia. Use também para perguntas sobre clima histórico, ex.: 'como estava o tempo nos últimos 30 dias?'."

  params do
    string :start_date, required: true,
           description: "Data inicial no formato AAAA-MM-DD. Pode ser uma data passada."
    string :end_date, required: false,
           description: "Data final no formato AAAA-MM-DD, inclusiva. Se omitida, usa start_date (consulta apenas um dia)."
  end

  def execute(start_date:, end_date: nil)
    finish = end_date.presence || start_date
    days = Weather::Mock.range(start_date, finish)
    {
      start_date: start_date,
      end_date:   finish,
      days:       days
    }
  rescue Date::Error
    { error: "Data inválida. Use o formato AAAA-MM-DD." }
  end
end
