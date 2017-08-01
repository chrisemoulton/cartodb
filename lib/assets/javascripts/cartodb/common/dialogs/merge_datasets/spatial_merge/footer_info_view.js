var cdb = require('cartodb.js-v3');
var presentAlias = require('../../../view_helpers/alias_presenter');

/**
 * View to indicate the selected key columns relationship and merge method relationship.
 */
module.exports = cdb.core.View.extend({

  initialize: function() {
    this._initBinds();
  },

  render: function() {
    var rightColumns = this.model.get('rightColumns');
    var leftTable = this.model.get('leftTable');
    var leftTableName = presentAlias({
      user: this.options.user,
      original: leftTable.get('name'),
      alias: leftTable.get('name_alias')
    });

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
    this.$('.js-merge-method-name').text(selectedMergMethod ? selectedMergMethod.NAME : '');
    var rightTableData = this.model.get('rightTableData');
    var name = presentAlias({
      user: this.options.user,
      original: rightTableData.name,
      alias: rightTableData.name_alias
    });

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
