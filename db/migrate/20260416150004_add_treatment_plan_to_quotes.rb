class AddTreatmentPlanToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_reference :quotes, :treatment_plan, null: true, foreign_key: true
  end
end
