require_relative '../../../../lib/profile_attributes'

class Api::Json::ProfileAttributesController < Api::ApplicationController
  include CartoDB

  def show
    render json: current_user.nil? ? {} : CartoDB::ProfileAttributes.load(current_user, session)
  end

end
