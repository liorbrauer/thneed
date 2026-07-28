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

  it "accepts Action Mailbox reply recipients without accepting the whole domain" do
    main_cf = hatchbox.join("main.cf").read
    local_recipients = hatchbox.join("local_recipients").read
    root_deploy = hatchbox.join("root-deploy").read

    expect(main_cf).to include("regexp:/etc/postfix/local_recipients")
    expect(local_recipients).to include("/^thneed-[[:alnum:]]+@thneed[.]org$/ OK")
    expect(root_deploy).to include("transport local_recipients /etc/postfix/")
    expect(main_cf).not_to match(/^local_recipient_maps\s*=\s*$/)
  end

  it "uses IPv4 for the initial mail launch" do
    expect(hatchbox.join("main.cf").read).to match(/^inet_protocols = ipv4$/)
  end

  it "relays inbound mail without booting the full Rails application" do
    ingress = Pathname(__dir__).join("../../script/thneed-ingress").expand_path.read

    expect(ingress).to include("require action_mailbox/relayer")
      .or include("-raction_mailbox/relayer")
    expect(ingress).to include("ActionMailbox::Relayer.new")
    expect(ingress).not_to include("exec rails action_mailbox:ingress:postfix")
  end

  it "shares the Hatchbox ingress secret with the Rails relay controller" do
    production = Pathname(__dir__).join("../../config/environments/production.rb").expand_path.read

    expect(production).to include(
      'ENV["RAILS_INBOUND_EMAIL_PASSWORD"] ||= ENV["INGRESS_PASSWORD"] ||'
    )
    expect(production).to include("shared/etc/ingress_password")
    expect(ingress = Pathname(__dir__).join("../../script/thneed-ingress").expand_path.read)
      .to include("shared/etc/ingress_password")
  end
end
