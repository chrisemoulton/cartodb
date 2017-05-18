cdb.admin.ProfileAttributes = cdb.core.Model.extend({

  /**
   * Create a ProfileAttributes model which stores
   * the provided 'profileAttributes' locally as
   * 'attrs'.
   * @param profileAttributes profile attribute as JSON.
   */
  initialize: function (profileAttributes) {
    return cdb.core.Model.prototype.initialize.call(this, {
      attrs: profileAttributes
    });
  },

  /**
   * Check whether this has the attribute identified by 'name'.
   * @param name
   * @returns {boolean} true if the model has a value specified
   *                    for the attribute else false.
   */
  hasAttribute: function (name) {
    return name in this.attrs;
  },

  /**
   * Return the value for the attribute identified by 'name'.
   * Behavior is undefined if hasAttribute(name) returns false.
   * @param name
   */
  getAttribute: function (name) {
    return this.attrs[name];
  },

});
