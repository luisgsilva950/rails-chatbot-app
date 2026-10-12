# frozen_string_literal: true

# This migration comes from ruby_llm_evaluations (originally 20261011000000)
class CreateAgentEvaluationHistory < ActiveRecord::Migration[7.1]
  RUNS = "ruby_llm_evaluations_runs"
  CASES = "ruby_llm_evaluations_case_results"
  METRICS = "ruby_llm_evaluations_metric_results"
  LEGACY = "ruby_llm_evaluations_legacy_runs"
  LEGACY_VERSIONS = "ruby_llm_evaluations_schema_versions"

  class LegacyRun < ActiveRecord::Base
    self.table_name = LEGACY
    self.primary_key = "sequence"
  end

  class LegacyVersion < ActiveRecord::Base
    self.table_name = LEGACY_VERSIONS
    self.primary_key = "version"
  end

  class MigratedRun < ActiveRecord::Base
    self.table_name = RUNS
  end

  class MigratedCase < ActiveRecord::Base
    self.table_name = CASES
  end

  class MigratedMetric < ActiveRecord::Base
    self.table_name = METRICS
  end

  def up
    raise ActiveRecord::MigrationError, "evaluation history requires PostgreSQL" unless connection.adapter_name == "PostgreSQL"

    legacy = table_exists?(RUNS) && column_exists?(RUNS, :payload)
    if legacy
      unless table_exists?(LEGACY_VERSIONS) && LegacyVersion.pluck(:version) == [ 1 ]
        raise ActiveRecord::MigrationError, "unsupported legacy evaluation history version"
      end
      rename_table RUNS, LEGACY
    elsif table_exists?(RUNS)
      raise ActiveRecord::MigrationError, "evaluation model tables already exist without this migration"
    end

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
      table.jsonb :criteria, null: false, default: {}
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

    if legacy
      copy_legacy_history
      connection.reset_pk_sequence!(RUNS, "sequence", "#{RUNS}_sequence_seq")
      drop_table LEGACY
    end
    drop_table LEGACY_VERSIONS if table_exists?(LEGACY_VERSIONS)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "evaluation history migration preserves append-only evidence"
  end

  private

  def copy_legacy_history
    [ LegacyRun, MigratedRun, MigratedCase, MigratedMetric ].each(&:reset_column_information)
    LegacyRun.find_each do |row|
      value = row.payload
      run = MigratedRun.create!(
        id: value.fetch("id"), sequence: row.sequence, suite: value.fetch("suite"), agent: value.fetch("agent"),
        version: value.fetch("version", "1"), suite_digest: value.fetch("suite_digest"),
        started_at: value.fetch("started_at"), finished_at: value.fetch("finished_at"),
        status: value.fetch("status"), metadata: value.fetch("metadata", {}), summary: value.fetch("summary")
      )
      value.fetch("cases").each_with_index do |item, position|
        metrics = item.fetch("evaluations")
        question = MigratedCase.create!(
          run_id: run.id, position: position, case_id: item.fetch("id"), name: item.fetch("name"),
          question: item["input"], expected_answer: item["expected"], expected_actions: item["expected_actions"],
          criteria: metrics.to_h { |metric| [ metric.fetch("name"), metric.fetch("threshold") ] },
          metadata: item.fetch("metadata", {}), output: item["output"], status: item.fetch("status"),
          duration_ms: item.fetch("duration_ms"), input_tokens: item["input_tokens"], output_tokens: item["output_tokens"],
          cost: item["cost"], actions: item["actions"], response_metadata: item["response_metadata"], error_details: item["error"]
        )
        metrics.each_with_index do |metric, metric_position|
          MigratedMetric.create!(
            case_result_id: question.id, position: metric_position, name: metric.fetch("name"),
            threshold: metric.fetch("threshold"), score: metric["score"], passed: metric.fetch("passed"),
            reason: metric["reason"], error_details: metric["error"]
          )
        end
      end
    end
  end
end
