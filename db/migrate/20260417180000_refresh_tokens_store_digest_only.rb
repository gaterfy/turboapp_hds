# frozen_string_literal: true

class RefreshTokensStoreDigestOnly < ActiveRecord::Migration[8.0]
  def up
    add_column :refresh_tokens, :token_digest, :string

    say_with_time "backfill_refresh_token_digests" do
      pepper = refresh_pepper
      connection.select_all(
        "SELECT id, token FROM refresh_tokens WHERE token_digest IS NULL"
      ).each do |row|
        id  = row["id"]
        tok = row["token"]
        next if tok.blank?

        dig = OpenSSL::HMAC.hexdigest("SHA256", pepper, tok.to_s)
        execute(
          ActiveRecord::Base.sanitize_sql_array(
            [ "UPDATE refresh_tokens SET token_digest = ? WHERE id = ?", dig, id ]
          )
        )
      end
    end

    change_column_null :refresh_tokens, :token_digest, false

    remove_index :refresh_tokens, :token
    remove_column :refresh_tokens, :token

    add_index :refresh_tokens, :token_digest, unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Cannot restore plain refresh tokens from digests"
  end

  def refresh_pepper
    ENV.fetch("REFRESH_TOKEN_PEPPER") { Rails.application.credentials.secret_key_base }
  end
end
