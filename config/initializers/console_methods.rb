# typed: false

module Rails
  module ConsoleMethods
    def admin
      User.find_by! username: Rails.application.banned_domains_admin
    end
  end
end
