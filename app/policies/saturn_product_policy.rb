class SaturnProductPolicy < ApplicationPolicy
  def show?
    true
  end

  def manage?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def destroy?
    true
  end
end

