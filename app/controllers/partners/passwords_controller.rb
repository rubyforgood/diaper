# This exists so that we can override some of the devise resource
class Partners::PasswordsController < Devise::PasswordsController
  layout "devise_partner_users"

  skip_before_action :authorize_user
  skip_before_action :authenticate_user!
  # This one causes a redirect require_no_authentication
  skip_before_action :require_no_authentication

  # GET /resource/password/new
  def new
    super
  end

  # POST /resource/password
  def create
    super
  end

  # GET /resource/password/edit?reset_password_token=abcdef
  # def edit
  #   super
  # end

  # PUT /resource/password
  def update
    super
  end

  # protected

  # def after_resetting_password_path_for(resource)
  #   super(resource)
  # end

  # The path used after sending reset password instructions
  # def after_sending_reset_password_instructions_path_for(resource_name)
  #   super(resource_name)
  # end
end

