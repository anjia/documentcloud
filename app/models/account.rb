# An Account on DocumentCloud can be used to access the workspace and upload
# documents. Accounts have full priviledges for the entire organization, at the
# moment.
class Account < ActiveRecord::Base

  ADMINISTRATOR = 1
  CONTRIBUTOR   = 2

  # Associations:
  belongs_to  :organization
  has_many    :projects,          :dependent => :destroy
  has_many    :processing_jobs, :dependent => :destroy
  has_one     :security_key,    :dependent => :destroy, :as => :securable

  # Validations:
  validates_presence_of   :first_name, :last_name, :email
  validates_format_of     :email, :with => DC::Validators::EMAIL
  validates_uniqueness_of :email

  # Delegations:
  delegate :name, :to => :organization, :prefix => true

  # Attempt to log in with an email address and password.
  def self.log_in(email, password, session)
    account = Account.find_by_email(email)
    return false unless account && account.password == password
    account.authenticate(session)
  end

  # Save this account as the current account in the session. Logs a visitor in.
  def authenticate(session)
    session['account_id'] = id
    session['organization_id'] = organization_id
    self
  end

  # An account owns a resource if it's tagged with the account_id.
  def owns?(resource)
    resource.account_id == id
  end

  # When an account is created by a third party, send an email with a secure
  # key to set the password.
  def send_login_instructions
    create_security_key if security_key.nil?
    LifecycleMailer.deliver_login_instructions(self)
  end

  # When a password reset request is made, send an email with a secure key to
  # reset the password.
  def send_reset_request
    create_security_key if security_key.nil?
    LifecycleMailer.deliver_reset_request(self)
  end

  # No middle names, for now.
  def full_name
    "#{first_name} #{last_name}"
  end

  # The ISO 8601-formatted email address.
  def rfc_email
    "\"#{full_name}\" <#{email}>"
  end

  # MD5 hash of processed email address, for use in Gravatar URLs.
  def hashed_email
    @hashed_email ||= Digest::MD5.hexdigest(email.downcase.gsub(/\s/, ''))
  end

  # Has this account been assigned, but never logged into, with no password set?
  def pending?
    !hashed_password
  end

  # It's slo-o-o-w to compare passwords. Which is a mixed bag, but mostly good.
  def password
    return false if hashed_password.nil?
    @password ||= BCrypt::Password.new(hashed_password)
  end

  # BCrypt'd passwords helpfully have the salt built-in.
  def password=(new_password)
    @password = BCrypt::Password.create(new_password, :cost => 8)
    self.hashed_password = @password
  end

  # The JSON representation of an account avoids sending down the password,
  # among other things, and includes extra attributes.
  def to_json(options = nil)
    {'id' => id, 'first_name' => first_name, 'last_name' => last_name,
     'email' => email, 'hashed_email' => hashed_email, 'pending' => pending?}.to_json
  end

end