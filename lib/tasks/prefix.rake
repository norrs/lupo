# frozen_string_literal: true

namespace :prefix do
  desc "Create index for prefixes"
  task :create_index => :environment do
    puts Prefix.create_index
  end

  desc "Delete index for prefixes"
  task :delete_index => :environment do
    puts Prefix.delete_index
  end

  desc "Upgrade index for prefixes"
  task :upgrade_index => :environment do
    puts Prefix.upgrade_index
  end

  desc "Show index stats for prefixes"
  task :index_stats => :environment do
    puts Prefix.index_stats
  end

  desc "Switch index for prefixes"
  task :switch_index => :environment do
    puts Prefix.switch_index
  end

  desc "Return active index for prefixes"
  task :active_index => :environment do
    puts Prefix.active_index + " is the active index."
  end

  desc "Start using alias indexes for prefixes"
  task :start_aliases => :environment do
    puts Prefix.start_aliases
  end

  desc "Monitor reindexing for prefixes"
  task :monitor_reindex => :environment do
    puts Prefix.monitor_reindex
  end

  desc "Wrap up starting using alias indexes for prefixes"
  task :finish_aliases => :environment do
    puts Prefix.finish_aliases
  end

  desc 'Import all prefixes'
  task :import => :environment do
    Prefix.all.each do |p|
      IndexJob.perform_later(p)
    end
  end

  desc 'Delete prefix and associated DOIs'
  task :delete => :environment do
    # These prefixes are used by multiple prefixes and can't be deleted
    prefixes_to_keep = %w(10.4124 10.4225 10.4226 10.4227)

    if ENV['PREFIX'].nil?
      puts "ENV['PREFIX'] is required."
      exit
    end

    if prefixes_to_keep.include?(ENV['PREFIX'])
      puts "Prefix #{ENV['PREFIX']} can't be deleted."
      exit
    end

    prefix = Prefix.where(prefix: ENV['PREFIX']).first
    if prefix.nil?
      puts "Prefix #{ENV['PREFIX']} not found."
      exit
    end

    PrefixPrefix.where('prefixes = ?', prefix.id).destroy_all
    puts "Prefix prefix deleted."

    ProviderPrefix.where('prefixes = ?', prefix.id).destroy_all
    puts "Provider prefix deleted."

    prefix.destroy
    puts "Prefix #{ENV['PREFIX']} deleted."

    # delete DOIs
    count = Doi.delete_dois_by_prefix(ENV['PREFIX'])
    puts "#{count} DOIs with prefix #{ENV['PREFIX']} deleted."
  end
end
