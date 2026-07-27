# typed: false

require "rails_helper"

describe Thneed::TaxonomyBootstrap do
  let(:moderator) { create(:user, :admin) }
  let(:io) { StringIO.new }
  let(:path) { Rails.root.join("spec/fixtures/thneed_taxonomy.yml") }

  def bootstrap(dry_run: false)
    described_class.new(path: path, moderator: moderator, dry_run: dry_run, io: io).call
  end

  it "creates configured categories and tags with attributed moderation entries" do
    expect { bootstrap }.to change(Category, :count).by(2).and change(Tag, :count).by(2)

    tag = Tag.find_by!(tag: "ask")
    expect(tag).to have_attributes(
      description: "Questions for the community",
      permit_by_new_users: false,
      category: Category.find_by!(category: "community")
    )
    expect(Moderation.where(moderator_user_id: moderator.id, category_id: tag.category_id)).to exist
    expect(Moderation.where(moderator_user_id: moderator.id, tag_id: tag.id)).to exist
  end

  it "is idempotent" do
    bootstrap

    expect { bootstrap }.to change(Category, :count).by(0)
      .and change(Tag, :count).by(0)
      .and change(Moderation, :count).by(0)
  end

  it "reports a dry run without writing records" do
    expect { bootstrap(dry_run: true) }.to change(Category, :count).by(0)
      .and change(Tag, :count).by(0)
      .and change(Moderation, :count).by(0)

    expect(io.string).to include("Would create 2 categories and 2 tags")
  end

  it "reports conflicts without making partial changes" do
    existing_category = create(:category, category: "other")
    create(:tag, category: existing_category, tag: "ask", description: "Changed by an admin")

    expect { bootstrap }.to raise_error(
      described_class::ConflictError,
      /Tag "ask" conflicts:.*description=.*category=/
    ).and change(Category, :count).by(0).and change(Tag, :count).by(0)
  end
end
