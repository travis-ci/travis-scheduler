class OwnerGroup < ActiveRecord::Base
end

class Subscription < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
end

class Organization < ActiveRecord::Base
  has_one :subscription, as: :owner
end

class User < ActiveRecord::Base
  has_one :subscription, as: :owner
end
