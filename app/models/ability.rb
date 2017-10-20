class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new(nil) # Guest user
    if user.role_id == "staff_admin"
      can :manage, :all
    elsif user.role_id == "staff_user"
      can :read, :all
      can :update, :all
    elsif user.role_id == "provider_admin"
      can [:update, :read], Provider, :symbol => user.provider_id
      can [:create, :update, :read], Client, :allocator => user.allocator
      can [:create, :update, :read], Doi, :datacentre => user.datacentre
      can [:update, :read], Prefix #, :datacentre => user.client_id
      can [:create, :update, :read], ClientPrefix #, :datacentre => user.client_id
      can [:read], ProviderPrefix #, :datacentre => user.client_id
      can [:create, :update, :read, :destroy], User, :provider_id => user.provider_id
    elsif user.role_id == "provider_user"
      can [:read], Provider, :symbol => user.provider_id
      can [:update, :read], Client, :allocator => user.allocator
      # can [:read], Prefix, :allocator => user.provider_id
      can [:read], Doi, :datacentre => user.datacentre
      can [:update, :read], User, :id => user.id
    elsif user.role_id == "client_admin"
      can [:read, :update], Client, :symbol => user.client_id
      can [:create, :update, :read], Doi, :datacentre => user.datacentre
      can [:create, :update, :read, :destroy], User, :client_id => user.client_id
    elsif user.role_id == "client_user"
      can [:read], Client, :symbol => user.client_id
      can [:read], Doi, :datacentre => user.datacentre
      can [:read], User, :id => user.id
    else
      can [:manage], Client, :provider_id => "SANDBOX"
      can [:read], Doi
    end
  end
end
