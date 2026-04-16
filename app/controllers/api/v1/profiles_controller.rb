# frozen_string_literal: true

module Api
  module V1
    class ProfilesController < Api::V1::BaseController
      def show
        audit "read", resource: current_account
        render_success profile_payload
      end

      private

      def profile_payload
        {
          id: current_account.id,
          email: current_account.email,
          account_type: current_account.account_type,
          organization: {
            id: current_organization.id,
            name: current_organization.name,
            slug: current_organization.slug
          },
          membership: {
            role: current_membership.role,
            joined_at: current_membership.joined_at
          }
        }
      end
    end
  end
end
