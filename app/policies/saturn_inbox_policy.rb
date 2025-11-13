class SaturnInboxPolicy < ApplicationPolicy
  def show?
    true
  end

  def create?
    true
  end

  def destroy?
    true
  end
end

