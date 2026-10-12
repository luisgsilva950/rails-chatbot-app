# frozen_string_literal: true

# This migration comes from ruby_llm_evaluations (originally 20261011000100)
class RenameCaseCriteriaToMinimumScores < ActiveRecord::Migration[7.1]
  def change
    rename_column :ruby_llm_evaluations_case_results, :criteria, :minimum_scores
  end
end
