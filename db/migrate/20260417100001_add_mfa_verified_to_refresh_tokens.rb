# frozen_string_literal: true

class AddMfaVerifiedToRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :refresh_tokens, :mfa_verified, :boolean, default: false, null: false
  end
end
