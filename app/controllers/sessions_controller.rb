class SessionsController < ApplicationController
  def create_token
    error_response("Wrong grant type.") && return if safe_params[:grant_type] != "password"
    error_response("Missing account ID or password.") && return if
      safe_params[:username].blank? || safe_params[:username] == "undefined" ||
      safe_params[:password].blank? || safe_params[:password] == "undefined"

    credentials = User.encode_auth_param(username: safe_params[:username], password: safe_params[:password])
    user = User.new(credentials, type: "basic")

    error_response(user.errors) && return if user.errors.present?
    error_response("Wrong account ID or password.") && return if user.role_id == "anonymous"

    render json: { "access_token" => user.jwt, "expires_in" => 3600 * 24 * 30 }.to_json, status: 200
  end

  def create_oidc_token
    error_response("Missing token.") && return if
    safe_params[:token].blank? || safe_params[:token] == "undefined" 

    user = User.new(safe_params[:token], type: "oidc")
    error_response(user.errors) && return if user.errors.present?

    render json: { "access_token" => user.jwt, "expires_in" => 3600 * 24 * 30 }.to_json, status: 200
  end

  def reset
    if safe_params[:username].blank?
      message = "Missing account ID."
      status = :ok
    else
      response = User.reset(safe_params[:username])
      if response.present?
        message = response[:message]
        status = response[:status]
      else
        message = "Account not found."
        status = :ok
      end
    end

    render json: { "message" => message }.to_json, status: status
  end

  private

  def error_response(message)
    status = 400
    logger.error message
    render json: { errors: [{ status: status.to_s, title: message }] }.to_json, status: status
  end

  def safe_params
    params.permit(:grant_type, :username, :password, :token, :client_id, :client_secret, :refresh_token, :session, :format, :controller, :action)
  end
end
