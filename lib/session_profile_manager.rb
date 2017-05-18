require 'active_support/json'
require_relative '../app/models/profile'

module CartoDB
  class SessionProfileManager

    # Instantiate a 'SessionProfileManager' with a reference to
    # a rails session.
    def initialize(session)
      @session = session
    end

    # Add 'names' to the overall set of session profile names.
    def register(names)
      set(get() | names)
    end

    # Remove 'names' from the overall set of session profile names.
    def remove(names)
      set(get() - names)
    end

    # Set all session profile names to the specified 'names',
    # replacing any existing session profile names.
    def set(names)
      @session[:session_profile_names] = ActiveSupport::JSON.encode(names)
    end

    # Return the session profile names matching those in 'names'
    # or all session profile names if 'names' is nil.
    def get(names=nil)
      session_names = @session.has_key?(:session_profile_names) ?
          ActiveSupport::JSON.decode(@session[:session_profile_names]) : []
      names ? names & session_names
            : session_names
    end

    # Return the session Profile models with the associated names
    # or all session Profile models in names in unspecified.
    def profiles(names=nil)
      Profile.where('name IN ?', get(names)).to_a
    end

  end
end