var cdb = require('cartodb.js-v3');
var SettingsDropdown = require('./user_settings/dropdown_view');
var $ = require('jquery-cdb-v3');
var CreateMapModel = require('../common/dialogs/create/create_map_model');
var ViewFactory = require('../common/view_factory');
var randomQuote = require('../common/view_helpers/random_quote');
var ExportMapModel = require('../models/export_map_model');


/**
 * View to render the user settings section in the header.
 * Expected to be created from existing DOM element.
 */
module.exports = cdb.core.View.extend({

  events: {
    'click .js-dropdown-target': '_createDropdown',
    'click .js-save-map': '_sampleMapSave'
  },

  initialize : function(opts) {
    this.currentUser = opts.currentUser;
    this.description = opts.description;
    this.vizName = opts.vizName;
    this.vizId = opts.vizId;
  },

  render: function() {
    var dashboardUrl = this.model.viewUrl().dashboard();
    var datasetsUrl = dashboardUrl.datasets();
    var mapsUrl = dashboardUrl.maps();

    this.$el.html(
      cdb.templates.getTemplate('public_common/sample_settings_template')({
        avatarUrl: this.model.get('avatar_url'),
        mapsUrl: mapsUrl,
        datasetsUrl: datasetsUrl,
        vis_name: window.vis_name,
        dashboard_url: dashboardUrl.toString()
      })
    );

    return this;
  },

  _getDataSet: function(name, layers) {
        var collection = new cdb.admin.Visualizations();

        collection.options.set({
          name: name,
          tags: '',
          shared: false,
          locked: false,
          only_liked: false,
          samples: false,
          order: 'updated_at',
          types: 'table,remote',
          type: '',
          deepInsights: false,
          per_page: 1000 // Increase this number, if the datalibrary datasets go beyond this number
        });

        collection.bind('loaded', function datasetsLoadedCallback(that) {
          collection.unbind('loaded', datasetsLoadedCallback);

          var ds = collection.where({ name: name });
          layers.push(ds[0]);
        });

      return collection.fetch();
  },

  _sampleMapSave: function() {
    if(true) {
      this._saveAsMap();
    }
    else {
      this._saveMap();
    }
  },

  _printExportState: function() {
    var state = this._exportMapModel.get('state');
    console.log('Export state: ' + state);
  },

  _saveAsMap: function() {
        // loading dialog box
        var loadingView = ViewFactory.createDialogByTemplate('common/templates/loading', {
          title: 'Saving map ...',
          quote: randomQuote()
        });

        loadingView.appendToBody();
    
        console.log('model url: ' + this.model.viewUrl());
        console.log(this.currentUser);

        //var ExportMapView = require('../common/dialogs/export_map/export_map_view');
        //var view = new ExportMapView({
        //        model: new cdb.admin.ExportMapModel({ 'visualization_id': this.vizId }),
        //          clean_on_hide: true,
        //          enter_to_confirm: true
        //      });

        //view.appendToBody();

        // Call export functionality
        // TODO - Need to get visualization ID
        //var ExportMapModel = require('../models/export_map_model');
        this._exportMapModel = new cdb.admin.ExportMapModel({
                visualization_id: this.vizId
              });
        this._exportMapModel.requestExport();

        this._exportMapModel.bind('change:state', function () {
          //this._printExportState();
          var state = this._exportMapModel.get('state');
          console.log('Export state: ' + state)
          if (state === 'complete') {
            // Download the file and trigger the import
            url = this._exportMapModel.get('url')
            console.log('export url: ' + url)

            var ConfigModel = require('../../cartodb3/data/config-model');
            var configModel = new ConfigModel({
                    base_url: this.model.viewUrl()
                  });

            var UserModel = require('../../cartodb3/data/user-model');
            this.userModel = new UserModel({
                id: this.currentUser.id,
                username: this.currentUser.attributes.username,
                organization: {
                          id: this.currentUser.groups.organization.id
                }
              }, {
                configModel: configModel
              });

            var UploadModel = require('../../cartodb3/data/upload-model');
            this._uploadModel = new UploadModel({
              type: 'file',
              value: this.model.viewUrl() + url,
              service_item_id: this.model.viewUrl() + url
            }, {
              userModel: this.userModel,
              configModel: configModel
            });
            console.log(this._uploadModel);

            this._uploadModel.bind('change:state'), function() {
              var state = this._uploadModel.get('state');
              console.log('Upload state: ' + state);
              if (state == 'complete') {
                loadingView.close();
              }
            }
            
            console.log('Uploading file');
            this._uploadModel.upload();
            console.log('upload state: ' + this._uploadModel.get('state'));
            //loadingView.close();
          } else if (state === 'failure') {
            return cdb.templates.getTemplate('common/templates/fail')({
              msg: 'Export has failed'
            });
          }
        }, this);
  },

  _saveMap: function() {

        var loadingView = ViewFactory.createDialogByTemplate('common/templates/loading', {
          title: 'Saving map ...',
          quote: randomQuote()
        });

        var currentUser = this.currentUser;
        var vizName = this.vizName;
        var description = this.description;
   
        loadingView.appendToBody();

        var datasets = window.datalib_layers;
        var layers = [];
        var promises = [];

        for(var i=0; i<datasets.length; ++i) {
          promises.push(this._getDataSet(datasets[i], layers));
        }

        //Now, go through all the deferred promises :-)
        $.when.apply($, promises).done(function() {

          var d = {
              type: 'map',
              listing: 'import',
              selectedItems: layers
            }
   
          var CreateMapModel = require('../common/dialogs/create/create_map_model');
          

          var createModel;
          d = d || {};
          if (d.type === 'dataset') {
            createModel = new CreateDatasetModel({}, {
              user: currentUser
            });
          } 
          else {
            var options = {};
            if (d.listing !== undefined) {
              options.listing = d.listing;
          }

          var viz_descriptionTag = description;
          var xmlParser = new DOMParser();
          xmlDoc = xmlParser.parseFromString(viz_descriptionTag, "text/xml");
          var viz_description = "";
          if (xmlDoc.getElementsByTagName("p").length > 0) {
            viz_description = xmlDoc.getElementsByTagName("p")[0].childNodes[0].nodeValue;
          }

          createModel = new CreateMapModel(
            options, _.extend({user: currentUser,
                               mapName: vizName + " (Copy)",
                               description: viz_description
                                },d) );
        }

        createModel.bind('datasetCreated', function(tableMetadata) {
          if (router.model.isDatasets()) {
            var vis = new cdb.admin.Visualization({ type: 'table' });
            vis.permission.owner = currentUser;
            vis.set('table', tableMetadata.toJSON());
            window.location = vis.viewUrl(currentUser).edit();
          } else {
            var vis = new cdb.admin.Visualization({ name: DEFAULT_VIS_NAME });
            vis.save({
              tables: [ tableMetadata.get('id') ]
            },{
              success: function(m) {
                window.location = vis.viewUrl(currentUser).edit();
              },
              error: function(e) {
                loadingView.close();
                collection.trigger('error');
              }
            });
          }
        }, this);

        createModel.viewsReady();


      });


  },

  _openCreateDialog : function(d, loadingView) {
        var CreateMapModel = require('../common/dialogs/create/create_map_model');

        var createModel;
        d = d || {};
        if (d.type === 'dataset') {
          createModel = new CreateDatasetModel({}, {
            user: currentUser
          });
        } else {
          var options = {};
          if (d.listing !== undefined) {
            options.listing = d.listing;
          }

          var viz_descriptionTag = window.vizdata.description;
          var xmlParser = new DOMParser();
          xmlDoc = xmlParser.parseFromString(viz_descriptionTag, "text/xml");
          var viz_description = "";
          if (xmlDoc.getElementsByTagName("p").length > 0) {
            viz_description = xmlDoc.getElementsByTagName("p")[0].childNodes[0].nodeValue;
          }

          createModel = new CreateMapModel(
            options, _.extend({user: currentUser,
                               mapName: window.vis_name,
                               description: viz_description
                                },d) );
        }


        createModel.bind('datasetCreated', function(tableMetadata) {
          if (router.model.isDatasets()) {
            var vis = new cdb.admin.Visualization({ type: 'table' });
            vis.permission.owner = currentUser;
            vis.set('table', tableMetadata.toJSON());
            window.location = vis.viewUrl(currentUser).edit();
          } else {
            var vis = new cdb.admin.Visualization({ name: DEFAULT_VIS_NAME });
            vis.save({
              tables: [ tableMetadata.get('id') ]
            },{
              success: function(m) {
                window.location = vis.viewUrl(currentUser).edit();
              },
              error: function(e) {
                loadingView.close();
                collection.trigger('error');
              }
            });
          }
        }, this);

      createModel.viewsReady();
    },


  _createDropdown: function(ev) {
    this.killEvent(ev);
    cdb.god.trigger('closeDialogs');

    var view = new SettingsDropdown({
      target: $(ev.target),
      model: this.model, // user
      horizontal_offset: 18
    });
    view.render();

    view.on('onDropdownHidden', function() {
      view.clean();
    }, this);

    view.open();
  }

});
