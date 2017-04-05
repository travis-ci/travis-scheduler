class OwnerGroup < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
end

class Subscription < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
end

class Organization < ActiveRecord::Base
  has_one :subscription, as: :owner
  has_one :owner_group, as: :owner
end

class User < ActiveRecord::Base
  has_one :subscription, as: :owner
  has_one :owner_group, as: :owner
end
