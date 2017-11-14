
class Api::Json::ProfileAttributesController < Api::ApplicationController
  include CartoDB

  def show
    render json: current_user.nil? ? {} : current_user.profile_attributes
  end

end
