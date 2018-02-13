module Carto
  module Api
    class SamplesController < ::Api::ApplicationController

      ssl_required :show

      # TODO: compare with older, there seems to be more optional authentication endpoints
      before_filter :id_and_schema_from_params

      rescue_from Carto::LoadError, with: :rescue_from_carto_error
      rescue_from Carto::UUIDParameterFormatError, with: :rescue_from_carto_error

      def show
        # Lookup visualization
        viz = Carto::Visualization.where(id: @id).first
        if viz && viz.user_id == sample_maps_user.id
           redirect_to CartoDB.url(self, 'public_visualizations_sample_map', { id: params[:id], sample_user: sample_maps_user.username }, current_user)
        else
          # Re-route to default page and show error message
          redirect_to CartoDB.url(self, 'maps_samples', {}, current_user)
        end
      rescue KeyError
        head(404)
      end

      def id_and_schema_from_params
        @id = params.fetch('id', nil)
      end
    end
  end
end
