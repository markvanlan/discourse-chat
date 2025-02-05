# frozen_string_literal: true

class ChatChannelSearchSerializer < ApplicationSerializer
  has_many :public_channels, serializer: ChatChannelSerializer, embed: :objects
  has_many :direct_message_channels, serializer: ChatChannelSerializer, embed: :objects
  has_many :users, serializer: BasicUserSerializer, embed: :objects

  def public_channels
    object[:public_channels]
  end

  def direct_message_channels
    object[:direct_message_channels]
  end

  def users
    object[:users]
  end
end
