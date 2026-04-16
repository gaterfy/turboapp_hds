class AddAiColumnsToConsultations < ActiveRecord::Migration[8.0]
  def change
    add_column :consultations, :ai_generated_report,   :text
    add_column :consultations, :ai_colleague_letter,   :jsonb, default: {}
    add_column :consultations, :ai_generated_at,       :datetime
    add_column :consultations, :ai_model_used,         :string
  end
end
