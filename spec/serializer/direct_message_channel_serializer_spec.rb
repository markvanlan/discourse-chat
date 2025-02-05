# frozen_string_literal: true

require 'rails_helper'

describe DirectMessageChannelSerializer do
  describe "#user" do
    it "returns you when there are two of us" do
      me = Fabricate.build(:user)
      you = Fabricate.build(:user)
      direct_message_channel = Fabricate.build(:direct_message_channel, users: [me, you])

      serializer = DirectMessageChannelSerializer.new(direct_message_channel, scope: Guardian.new(me), root: false)

      expect(serializer.users).to eq([you])
    end

    it "returns you both if there are three of us" do
      me = Fabricate.build(:user)
      you = Fabricate.build(:user)
      other_you = Fabricate.build(:user)
      direct_message_channel = Fabricate.build(:direct_message_channel, users: [me, you, other_you])

      serializer = DirectMessageChannelSerializer.new(direct_message_channel, scope: Guardian.new(me), root: false)

      expect(serializer.users).to match_array([you, other_you])
    end

    it "returns me if there is only me" do
      me = Fabricate.build(:user)
      direct_message_channel = Fabricate.build(:direct_message_channel, users: [me])

      serializer = DirectMessageChannelSerializer.new(direct_message_channel, scope: Guardian.new(me), root: false)

      expect(serializer.users).to eq([me])
    end
  end
end
