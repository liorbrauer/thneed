# frozen_string_literal: true

require "pathname"

RSpec.describe "Hatchbox mail configuration" do
  let(:hatchbox) { Pathname(__dir__).join("../..", "hatchbox").expand_path }

  it "forwards every administrative alias directly to the configured address" do
    aliases = hatchbox.join("aliases").read.lines.filter_map do |line|
      line = line.sub(/#.*/, "").strip
      line.split(":", 2).first if line.include?(":") && line != "nobody: /dev/null"
    end
    virtual_aliases = hatchbox.join("virtual_aliases").read

    aliases.each do |name|
      expect(virtual_aliases).to include("#{name}@thneed.org ADMIN_EMAIL")
    end
    expect(virtual_aliases).not_to match(/^@thneed\.org\s/m)
  end

  it "substitutes the administrator address before building the virtual alias map" do
    root_deploy = hatchbox.join("root-deploy").read

    substitution = root_deploy.index('sed -i "s/ADMIN_EMAIL/$ADMIN_EMAIL/g" /etc/postfix/virtual_aliases')
    postmap = root_deploy.index("postmap /etc/postfix/virtual_aliases")

    expect(substitution).to be < postmap
  end

  it "creates the DKIM key directory before generating the key" do
    root_deploy = hatchbox.join("root-deploy").read

    directory = root_deploy.index("install -d -o opendkim -g opendkim -m 0750 /etc/dkimkeys")
    keygen = root_deploy.index("opendkim-genkey")

    expect(directory).to be < keygen
    expect(root_deploy).not_to include("cp opendkim.m4")
  end

  it "preserves the domain transport used by Action Mailbox replies" do
    expect(hatchbox.join("transport").read).to include("thneed.org thneed-ingress:")
    expect(hatchbox.join("master.cf").read).to include("thneed-ingress")
  end
end
