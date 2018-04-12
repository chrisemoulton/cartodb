# encoding: utf-8

require_relative '../../../spec_helper'
require 'factories/carto_visualizations'
require_relative '../../../../app/controllers/carto/api/samples_controller'

describe Carto::Api::SamplesController do
  include Carto::Factories::Visualizations

  before(:all) do
    @not_sample_user = FactoryGirl.create(:carto_user)
    @sample_user = FactoryGirl.create(:carto_user, { username: Cartodb.config[:map_samples]['username'] } )
  end

  before(:each) do
    bypass_named_maps
    @headers = {
      'CONTENT_TYPE' => 'application/json'
    }
    host! "#{@not_sample_user.subdomain}.localhost.lan"
  end

  after(:all) do
    bypass_named_maps
    @sample_user.destroy
    @not_sample_user.destroy
  end

  let(:params) { { :api_key => @not_sample_user.api_key } }

  describe 'GET /api/v1/sample_link/:id' do
    it 'opens sample map with valid id' do
      map, table, table_visualization, visualization = create_full_visualization(@sample_user)
      begin
        get api_v1_samples_link_show_url(params.merge(id: visualization.id)), {}, @headers
        expect(response.status).to eq(302) # Re-direct
        expect(response.location).to eq(public_visualizations_sample_map_url({id: visualization.id, sample_user: @sample_user.username, port: 53716}))
      ensure
        destroy_full_visualization(map, table, table_visualization, visualization)
      end
    end

    it 'opens data library to sample map view with non-sample user id' do
        map, table, table_visualization, visualization = create_full_visualization(@not_sample_user)
      begin
        get api_v1_samples_link_show_url(params.merge(id: visualization.id)), {}, @headers
        expect(response.status).to eq(302) # Re-direct
        expect(response.location).to eq(maps_samples_url(port: 53716))
      ensure
        destroy_full_visualization(map, table, table_visualization, visualization)
      end
    end

    it 'opens data library to sample map view with non-existent id' do
      get api_v1_samples_link_show_url(params.merge(id: '00011000-0000-0000-0000-000100010001')), nil, @headers
      expect(response.status).to eq(302) # Re-direct
      expect(response.location).to eq(maps_samples_url(port: 53716))
    end

    it 'opens data library to sample map view with invalid uuid format id' do
      get api_v1_samples_link_show_url(params.merge(id: 'deadbeef')), nil, @headers
      expect(response.status).to eq(302) # Re-direct
      expect(response.location).to eq(maps_samples_url(port: 53716))
    end
  end
end
