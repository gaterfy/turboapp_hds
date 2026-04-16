# frozen_string_literal: true

# Stores revoked JWT JTI values until their natural expiration.
# A background job can clean up rows where exp < NOW().
class CreateJwtDenylist < ActiveRecord::Migration[8.0]
  def change
    create_table :jwt_denylist do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false

      t.timestamps null: false
    end

    add_index :jwt_denylist, :jti, unique: true
    add_index :jwt_denylist, :exp
  end
end
