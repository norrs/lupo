FactoryGirl.define do
  factory :datacentre do
    comments { Faker::StarWars.character  }
    contact_email {Faker::Internet.email}
    contact_name {Faker::Name.name }
    created {Faker::Time.backward(14, :evening)}
    doi_quota_allowed 1
    doi_quota_used 1
    domains "MyString"
    is_active ""
    name "MyString"
    password "MyString"
    role_name "MyString"
    symbol {Faker::Code.asin + Faker::Code.isbn}
    updated {Faker::Time.backward(5, :evening)}
    version 1
    experiments "MyString"

    association :allocator, factory: :allocator, strategy: :build
  end
end
