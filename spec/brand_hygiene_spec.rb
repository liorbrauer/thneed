require "rails_helper"

RSpec.describe "shipped brand hygiene" do
  # These files intentionally preserve attribution, compatibility internals,
  # historical data, or links to the upstream project.
  let(:allowed_paths) do
    %w[
      README.md
      app/views/about/about.html.erb
      app/views/moderations/index.html.erb
      config/application.rb
      config/brakeman.ignore
      config/initializers/page_caching_monkeypatch.rb
      config/initializers/production.rb.sample
      config/initializers/session_store.rb
      config/initializers/telebugs.rb
      extras/html_encoder.rb
    ]
  end

  let(:scanned_paths) do
    %w[
      app/views
      app/javascript
      config
      hatchbox
      public
      script
      SECURITY.md
      Dockerfile.dev
      docker-compose.yaml
    ]
  end

  it "contains no stale Lobsters identity in public or operational surfaces" do
    files = scanned_paths.flat_map do |path|
      absolute = Rails.root.join(path)
      absolute.directory? ? Dir.glob(absolute.join("**", "*")).select { |entry| File.file?(entry) } : absolute.to_s
    end

    stale = files.filter_map do |file|
      relative = Pathname(file).relative_path_from(Rails.root).to_s
      next if allowed_paths.include?(relative)
      next if relative.start_with?("config/locales/")
      next if relative.start_with?("public/assets/")

      matches = File.readlines(file, encoding: "UTF-8").each_with_index.filter_map do |line, index|
        next unless line.match?(/lobste(?:rs|r|\.rs)/i)
        next if line.match?(%r{github\.com/lobsters/lobsters})
        next if %w[app/javascript/application.js app/javascript/user.js].include?(relative) &&
          line.match?(/\b_?Lobsters?(?:Function)?\b/)

        "#{relative}:#{index + 1}: #{line.strip}"
      end
      matches unless matches.empty?
    rescue ArgumentError
      nil # Binary public assets.
    end.flatten

    expect(stale).to eq([]), "Stale branding:\n#{stale.join("\n")}"
  end
end
