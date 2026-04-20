# frozen_string_literal: true

# Policy Pundit pour ActeCcam.
#
# Le catalogue CCAM est une nomenclature nationale publique : tout membre
# authentifié (admin, praticien ou assistant) peut le consulter.
# Aucune écriture n'est exposée via l'API (les imports se font via rake).
class ActeCcamPolicy < ApplicationPolicy
  # Lecture autorisée à tous les membres de l'organisation.
  def index?      = admin? || practitioner? || assistant?
  def show?       = admin? || practitioner? || assistant?
  def search?     = index?
  def categories? = index?
  def specialites?  = index?
  def regroupements? = index?

  class Scope < ApplicationPolicy::Scope
    # Le catalogue est partagé entre toutes les organisations : pas de filtre
    # par organisation sur cette table de référence.
    def resolve
      scope.all
    end
  end
end
