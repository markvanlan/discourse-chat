# frozen_string_literal: true

module ChatHelper
  def self.make_messages!(topic, users, count)
    users = [users] unless Array === users
    raise ArgumentError if users.length <= 0

    topic = Fabricate(:topic) unless topic
    chat_channel = Fabricate(:chat_channel, chatable: topic)

    count.times do |n|
      ChatMessage.new(
        chat_channel: chat_channel,
        user: users[n % users.length],
        message: "Chat message for test #{n}",
      ).save!
    end
  end
end
