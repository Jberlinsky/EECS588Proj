class ApiKey
  include DataMapper::Resource

  property :id, Serial
  property :api_key, Text
  property :uses, Integer
  property :provider, String

  validates_uniqueness_of :api_key

  def used(times)
    self.uses -= times
  end

  def has_uses?(uses)
    self.uses >= uses
  end
end
