var cdb = require('cartodb.js-v3');

/**
 * View to indicate the selected key columns relationship and merge method relationship.
 */
module.exports = cdb.core.View.extend({

  initialize: function() {
    this._initBinds();
  },

  render: function() {
    var rightColumns = this.model.get('rightColumns');
    var leftTableName = '';
    if (this.options.user.featureEnabled('aliases')) {
      if (this.model.get('leftTable').get('name_alias')) {
        leftTableName = this.model.get('leftTable').get('name_alias') + ' ('+ this.model.get('leftTable').get('name') + ')';
      } else {
        this.model.get('leftTable').get('name');
      }
    } else {
      if (vis.get('table').name_alias) {
        leftTableName = this.model.get('leftTable').get('name_alias');
      } else {
        leftTableName = this.model.get('leftTable').get('name');
      }
    }
    this.$el.html(
      this.getTemplate('common/dialogs/merge_datasets/spatial_merge/footer_info')({
        leftTableName: leftTableName,
        rightColumnName: rightColumns ? rightColumns.get('name') : ''
      })
    );
    return this;
  },

  _initBinds: function() {
    var rightColumns = this.model.get('rightColumns');
    rightColumns.bind('change:selected', this._updatePieces, this);
    this.add_related_model(rightColumns);

    var mergeMethods = this.model.get('mergeMethods');
    mergeMethods.bind('change:selected', this._updatePieces, this);
    this.add_related_model(mergeMethods);
  },

  _updatePieces: function() {
    var selectedMergMethod = this.model.selectedMergeMethod();
    var aliasUser = this.options.user.featureEnabled('aliases');
    this.$('.js-merge-method-name').text(selectedMergMethod ? selectedMergMethod.NAME : '');
    var name = '';
    if (this.model.isCountMergeMethod(selectedMergMethod)) {
      if (aliasUser) {
        if (this.model.get('rightTableData').name_alias) {
          name = this.model.get('rightTableData').name_alias + '(' + this.model.get('rightTableData').name + ')';
        } else {
          name = this.model.get('rightTableData').name;
        }
      } else {
        if (this.model.get('rightTableData').name_alias) {
          name = this.model.get('rightTableData').name_alias;
        } else {
          name = this.model.get('rightTableData').name;
        }
      }
    this._changeRightPiece(name);
    } else {
      var m = this.model.selectedRightMergeColumn();
      if (m) {
        if (m.get('alias')) {
          name = m.get('alias');
        } else {
          name = m.get('name');
        }
      }
      this._changeRightPiece(name);
    }
  },

  _changeRightPiece: function(text) {
    this.$('.js-right')
      .text(text || '')
      .toggleClass('is-placeholder', !text);
  }

});
