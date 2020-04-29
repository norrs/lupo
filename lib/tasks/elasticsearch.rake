# frozen_string_literal: true

require "elasticsearch/rails/tasks/import"

namespace :elasticsearch do
  desc "create all indexes"
  task create_all_indexes: :environment do
    Rake::Task["provider:create_index"].invoke
    Rake::Task["client:create_index"].invoke
    Rake::Task["prefix:create_index"].invoke
    Rake::Task["provider_prefix:create_index"].invoke
    Rake::Task["client_prefix:create_index"].invoke
    Rake::Task["doi:create_index"].invoke
    Rake::Task["event:create_index"].invoke
    Rake::Task["activity:create_index"].invoke
  end

  desc "delete all indexes"
  task delete_all_indexes: :environment do
    Rake::Task["provider:delete_index"].invoke
    Rake::Task["client:delete_index"].invoke
    Rake::Task["prefix:delete_index"].invoke
    Rake::Task["provider_prefix:delete_index"].invoke
    Rake::Task["client_prefix:delete_index"].invoke
    Rake::Task["doi:delete_index"].invoke
    Rake::Task["event:delete_index"].invoke
    Rake::Task["activity:delete_index"].invoke
  end
end
