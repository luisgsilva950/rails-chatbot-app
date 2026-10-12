# frozen_string_literal: true

# This migration comes from ruby_llm_evaluations (originally 20261011000000)
class CreateAgentEvaluationHistory < ActiveRecord::Migration[7.1]
  RUNS = "ruby_llm_evaluations_runs"
  CASES = "ruby_llm_evaluations_case_results"
  METRICS = "ruby_llm_evaluations_metric_results"

  def change
    raise ActiveRecord::MigrationError, "evaluation history requires PostgreSQL" unless connection.adapter_name == "PostgreSQL"

    create_table RUNS, id: :string do |table|
      table.bigserial :sequence, null: false
      table.string :suite, null: false
      table.string :agent, null: false
      table.string :version, null: false, default: "1"
      table.string :suite_digest, null: false
      table.column :started_at, :timestamptz, null: false, precision: 6
      table.column :finished_at, :timestamptz, null: false, precision: 6
      table.string :status, null: false
      table.jsonb :metadata, null: false, default: {}
      table.jsonb :summary, null: false
      table.timestamps precision: 6
    end
    add_index RUNS, :sequence, unique: true
    add_index RUNS, [ :started_at, :sequence ], order: { started_at: :desc, sequence: :desc }, name: "rle_runs_recent"
    add_index RUNS, [ :suite, :agent, :suite_digest, :started_at, :sequence ],
              order: { started_at: :desc, sequence: :desc }, name: "rle_runs_comparable"

    create_table CASES do |table|
      table.references :run, type: :string, null: false, foreign_key: { to_table: RUNS }
      table.integer :position, null: false
      table.string :case_id, null: false
      table.text :name, null: false
      table.jsonb :question
      table.jsonb :expected_answer
      table.jsonb :expected_actions
      table.jsonb :minimum_scores, null: false, default: {}
      table.jsonb :metadata, null: false, default: {}
      table.jsonb :output
      table.string :status, null: false
      table.float :duration_ms, null: false
      table.bigint :input_tokens
      table.bigint :output_tokens
      table.float :cost
      table.jsonb :actions
      table.jsonb :response_metadata
      table.jsonb :error_details
      table.timestamps precision: 6
    end
    add_index CASES, [ :run_id, :position ], unique: true, name: "rle_case_order"
    add_index CASES, [ :run_id, :case_id ], unique: true, name: "rle_case_identity"

    create_table METRICS do |table|
      table.references :case_result, null: false, foreign_key: { to_table: CASES }
      table.integer :position, null: false
      table.string :name, null: false
      table.float :threshold, null: false
      table.float :score
      table.boolean :passed, null: false
      table.text :reason
      table.jsonb :error_details
      table.timestamps precision: 6
    end
    add_index METRICS, [ :case_result_id, :position ], unique: true, name: "rle_metric_order"
    add_index METRICS, [ :case_result_id, :name ], unique: true, name: "rle_metric_identity"
  end
end
