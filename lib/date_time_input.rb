module DateTimeInput
  def self.hash_to_datetime h
    date = h["date"]
    time = h["time"]

    DateTime.strptime "#{date} #{time}", "%m/%d/%Y %l:%M %p"
  end
end
