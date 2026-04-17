# frozen_string_literal: true

class AddTurboappMerchantIdToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :turboapp_merchant_id, :string
    add_index :organizations, :turboapp_merchant_id, unique: true, where: "turboapp_merchant_id IS NOT NULL"
  end
end
