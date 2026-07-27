# typed: false

namespace :thneed do
  desc "Create the initial Thneed categories and tags without overwriting existing records"
  task :bootstrap_taxonomy, [:username] => :environment do |_task, args|
    username = args[:username].presence
    abort 'Usage: bin/rails "thneed:bootstrap_taxonomy[admin_username]"' unless username

    moderator = User.find_by(username: username)
    unless moderator&.is_admin?
      abort "Could not find an administrator with username #{username.inspect}"
    end

    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])
    path = Rails.root.join("config/thneed_taxonomy.yml")

    begin
      Thneed::TaxonomyBootstrap.new(
        path: path,
        moderator: moderator,
        dry_run: dry_run
      ).call
    rescue Thneed::TaxonomyBootstrap::Error => e
      abort "Taxonomy bootstrap failed:\n#{e.message}"
    end
  end
end
