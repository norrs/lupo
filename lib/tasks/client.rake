# frozen_string_literal: true

namespace :client do
  desc "Create index for clients"
  task :create_index => :environment do
    puts Client.create_index
  end

  desc "Delete index for clients"
  task :delete_index => :environment do
    puts Client.delete_index(index: ENV["INDEX"])
  end

  desc "Upgrade index for clients"
  task :upgrade_index => :environment do
    puts Client.upgrade_index
  end

  desc "Show index stats for clients"
  task :index_stats => :environment do
    puts Client.index_stats
  end

  desc "Switch index for clients"
  task :switch_index => :environment do
    puts Client.switch_index
  end

  desc "Return active index for clients"
  task :active_index => :environment do
    puts Client.active_index + " is the active index."
  end

  desc "Monitor reindexing for clients"
  task :monitor_reindex => :environment do
    puts Client.monitor_reindex
  end

  desc 'Import all clients'
  task :import => :environment do
    Client.import(index: Client.inactive_index)
  end

  # desc 'Index DOIs by client'
  # task :index_all_dois => :environment do
  #   if ENV['CLIENT_ID'].nil?
  #     puts "ENV['CLIENT_ID'] is required."
  #     exit
  #   end

  #   client = Client.where(deleted_at: nil).where(symbol: ENV['CLIENT_ID']).first
  #   if client.nil?
  #     puts "Client not found for client ID #{ENV['CLIENT_ID']}."
  #     exit
  #   end

  #   # index DOIs for client
  #   # puts "#{client.dois.length} DOIs will be indexed."
  #   client.index_all_dois
  # end

  desc 'Import DOIs by client'
  task :import_dois => :environment do
    if ENV['CLIENT_ID'].nil?
      puts "ENV['CLIENT_ID'] is required."
      exit
    end

    client = Client.where(deleted_at: nil).where(symbol: ENV['CLIENT_ID']).first
    if client.nil?
      puts "Client not found for client ID #{ENV['CLIENT_ID']}."
      exit
    end

    # import DOIs for client
    puts "#{client.dois.length} DOIs will be imported."
    Doi.import_by_client(client_id: ENV['CLIENT_ID'])
  end

  desc 'Delete client transferred to other DOI registration agency'
  task :delete => :environment do
    if ENV['CLIENT_ID'].nil?
      puts "ENV['CLIENT_ID'] is required."
      exit
    end

    client = Client.where(deleted_at: nil).where(symbol: ENV['CLIENT_ID']).first
    if client.nil?
      puts "Client not found for client ID #{ENV['CLIENT_ID']}."
      exit
    end

    # These prefixes are used by multiple clients
    prefixes_to_keep = %w(10.4124 10.4225 10.4226 10.4227)

    # delete all associated prefixes and DOIs
    prefixes = client.prefixes.where.not('prefixes.uid IN (?)', prefixes_to_keep).pluck(:uid)
    prefixes.each do |prefix|
      ENV['PREFIX'] = prefix
      Rake::Task["prefix:delete"].reenable
      Rake::Task["prefix:delete"].invoke
    end

    if client.update_attributes(is_active: nil, deleted_at: Time.zone.now)
      client.send_delete_email(responsible_id: "admin") unless Rails.env.test?
      puts "Client with client ID #{ENV['CLIENT_ID']} deleted."
    else
      puts client.errors.inspect
    end
  end

  desc 'Transfer client'
  task :transfer => :environment do
    if ENV['CLIENT_ID'].nil?
      puts "ENV['CLIENT_ID'] is required."
      exit
    end

    client = Client.where(deleted_at: nil).where(symbol: ENV['CLIENT_ID']).first
    if client.nil?
      puts "Client not found for client ID #{ENV['CLIENT_ID']}."
      exit
    end

    if ENV['TARGET_ID'].nil?
      puts "ENV['TARGET_ID'] is required."
      exit
    end

    target = Client.where(deleted_at: nil).where(symbol: ENV['TARGET_ID']).first
    if target.nil?
      puts "Client not found for target ID #{ENV['TARGET_ID']}."
      exit
    end

    # These prefixes are used by multiple clients
    prefixes_to_keep = %w(10.4124 10.4225 10.4226 10.4227)

    # delete all associated prefixes
    prefixes = client.prefixes.where.not('prefixes.uid IN (?)', prefixes_to_keep)
    prefix_ids = client.prefixes.where.not('prefixes.uid IN (?)', prefixes_to_keep).pluck(:id)

    response = client.client_prefixes.destroy_all
    puts "#{response.count} client prefixes deleted."

    if prefix_ids.present?
      response = ProviderPrefix.where('prefix_id IN (?)', prefix_ids).destroy_all
      puts "#{response.count} provider prefixes deleted."
    end

    # update dois
    Doi.transfer(from_date: "2011-01-01", client_id: client.symbol, client_target_id: target.id)

    prefixes.each do |prefix|
      provider_prefix = ProviderPrefix.create(provider: target.provider, prefix: prefix)
      puts "Provider prefix for provider #{target.provider.symbol} and prefix #{prefix} created."
      client_prefix = ClientPrefix.create(client: target, prefix: prefix, provider_prefix: provider_prefix.id)
      puts "Client prefix for client #{target.symbol} and prefix #{prefix} created."
    end
  end
end
