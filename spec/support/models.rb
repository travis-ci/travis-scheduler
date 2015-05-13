ActiveRecord::Base.connection.drop_table "subscriptions" rescue nil
ActiveRecord::Base.connection.create_table "subscriptions", :force => true do |t|
  t.string   "cc_token"
  t.datetime "valid_to"
  t.integer  "owner_id"
  t.string   "owner_type"
  t.string   "first_name"
  t.string   "last_name"
  t.string   "company"
  t.string   "zip_code"
  t.string   "address"
  t.string   "address2"
  t.string   "city"
  t.string   "state"
  t.string   "country"
  t.string   "vat_id"
  t.string   "customer_id"
  t.datetime "created_at",         :null => false
  t.datetime "updated_at",         :null => false
  t.string   "cc_owner"
  t.string   "cc_last_digits"
  t.string   "cc_expiration_date"
  t.string   "billing_email"
  t.string   "selected_plan"
  t.string   "coupon"
  t.integer  "contact_id"
end

Organization.class_eval do
  has_one :subscription, as: :owner

  def subscribed?
    subscription.present? and subscription.active?
  end
end
