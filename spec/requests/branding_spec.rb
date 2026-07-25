require "rails_helper"

RSpec.describe "Thneed public identity", type: :request do
  it "brands the homepage and its metadata" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>Thneed</title>")
    expect(response.body).to include(">thneed</a>")
    expect(response.body).to include(Rails.application.og_description)
    expect(response.body).to include('title="Thneed"')
  end

  it "publishes the community policy" do
    get "/about"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("work, creativity, power, and agency")
    expect(response.body).to include("Curiosity and evidence")
    expect(response.body).to include("Transparent moderation")
    expect(response.body).to include("Ask Thneed")
  end

  it "publishes a factual privacy policy" do
    get "/privacy"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("operational logs")
    expect(response.body).to include("IP addresses")
    expect(response.body).to include("privacy@thneed.org")
  end

  it "permanently redirects the retired chat route" do
    get "/chat"

    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to("/about")
  end

  it "brands login and signup guidance without advertising chat" do
    get "/login"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to match(/chat room/i)

    get "/signup"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to match(%r{href="/chat"})
  end

  it "uses Thneed in feeds" do
    get "/rss"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/rss+xml")
    expect(response.body).to include("Thneed")
    expect(response.body).not_to include("https://lobste.rs")
  end

  it "ships branded search and error documents" do
    opensearch = Rails.public_path.join("opensearch.xml").read
    expect(opensearch).to include("<ShortName>Thneed</ShortName>")
    expect(opensearch).to include("https://thneed.org/search")
    expect(opensearch).not_to include("lobste.rs")

    %w[422 500 502 504].each do |status|
      page = Rails.public_path.join("#{status}.html").read
      expect(page).to include("Thneed HTTP #{status}")
      expect(page).not_to match(/lobsters|irc\.libera/i)
    end
  end
end
