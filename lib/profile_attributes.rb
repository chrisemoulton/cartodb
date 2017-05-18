require_relative 'session_profile_manager'

module CartoDB
  class ProfileAttributes

    def self.load(user, session)
      user_profiles = user.profiles
      profiles = (user_profiles + session_profiles(session)).uniq {|p| p.id}
      attrs_hash = profiles.reduce({}) do |attr, prof|
        attr.merge(prof.attrs_hash)
      end
      attrs_hash
    end

    private

    def initialize
    end

    def self.session_profiles(session)
      session_prof_mgr = CartoDB::SessionProfileManager.new(session)
      session_prof_mgr.profiles
    end

  end
end
