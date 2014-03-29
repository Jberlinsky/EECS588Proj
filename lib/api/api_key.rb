class Api::ApiKey
  attr_accessor :key
  attr_accessor :uses

  def initialize(key, uses = 0)
    @key = key
    @uses = uses
  end

  def used(times)
    self.uses -= times
  end

  def has_uses?(uses)
    self.uses >= uses
  end
end
