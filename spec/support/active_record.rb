require 'active_record'
require 'logger'
require 'fileutils'
require 'database_cleaner'

FileUtils.mkdir_p('log')

# TODO: why not make this use Travis::Database.connect ?
config = Travis.config.database.to_h
config.merge!('adapter' => 'jdbcpostgresql', 'username' => ENV['USER']) if RUBY_PLATFORM == 'java'
config['database'] = "travis_test"

ActiveRecord::Base.default_timezone = :utc
ActiveRecord::Base.logger = Logger.new('log/test.db.log')
ActiveRecord::Base.configurations = { 'test' => config }
ActiveRecord::Base.establish_connection('test')

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
