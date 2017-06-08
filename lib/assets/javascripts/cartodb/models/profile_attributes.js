cdb.admin.ProfileAttributes = cdb.core.Model.extend({

  /**
   * Do nothing. The ProfileAttributes model is read-only.
   */
  save: function () {
    console.log("ProfileAttributes.save unsupported - ProfileAttributes are read-only.");
  },

  /**
   * Return url for fetching this model. methods other than
   * GET are unsupported.
   * @param method http request method
   */
  url: function (method) {
    return "/api/v1/profile_attributes";
  },

});
