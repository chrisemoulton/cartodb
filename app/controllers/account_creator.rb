module AccountCreator
  def trigger_account_creation(account_creator)
    creation_data = account_creator.enqueue_creation(self)

    flash.now[:success] = 'User creation in progress'
    # Template variables
    @user_creation_id = creation_data[:id]
    @user_name = creation_data[:id]
    if params[:redirect_to].present?
      @redirect_url = CartoDB.base_url_from_request(self.request, @user) + params[:redirect_to]
    else
      @redirect_url = CartoDB.url(self, 'dashboard')
    end
  end
end
