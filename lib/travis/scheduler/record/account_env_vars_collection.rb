class AccountEnvVarsCollection < Collection
  include Enumerable

  model AccountEnvVars

  def initialize(relation)
    @collection = relation.to_a
  end

  def each(&block)
    @collection.each(&block)
  end

  def public
    find_all { |var| var.public }
  end
end
