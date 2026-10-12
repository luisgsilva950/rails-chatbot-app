# Evaluation-only agent; never participates in user chat turns.
class EvaluationJudgeAgent < RubyLLM::Agent
  model { ENV.fetch("EVALUATION_JUDGE_MODEL", RubyLLM.config.default_model) }
  instructions "You evaluate answer quality. Follow the rubric and return only the requested JSON."
end
