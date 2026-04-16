# frozen_string_literal: true

class CreateSsoAssertionDenylist < ActiveRecord::Migration[8.0]
  def change
    create_table :sso_assertion_denylist do |t|
      t.string   :jti, null: false, index: { unique: true }
      t.datetime :exp, null: false
      t.timestamps
    end
  end
end
