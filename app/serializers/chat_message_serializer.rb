# frozen_string_literal: true

class ChatMessageSerializer < ApplicationSerializer
  attributes :id,
    :message,
    :cooked,
    :action_code,
    :created_at,
    :excerpt,
    :deleted_at,
    :deleted_by_id,
    :reviewable_id,
    :user_flag_status,
    :edited,
    :reactions

  has_one :user, serializer: BasicUserSerializer, embed: :objects
  has_one :chat_webhook_event, serializer: ChatWebhookEventSerializer, embed: :objects
  has_one :in_reply_to, serializer: ChatInReplyToSerializer, embed: :objects
  has_many :uploads, serializer: UploadSerializer, embed: :objects

  def reactions
    reactions_hash = {}
    object.reactions.group_by(&:emoji).each do |emoji, reactions|
      users = reactions[0..6].map(&:user).filter { |user| user.id != scope&.user&.id }[0..5]

      reactions_hash[emoji] = {
        count: reactions.count,
        users: ActiveModel::ArraySerializer.new(users, each_serializer: BasicUserSerializer).as_json,
        reacted: users_reactions.include?(emoji)
      }
    end
    reactions_hash
  end

  def include_reactions?
    object.reactions.any?
  end

  def users_reactions
    @users_reactions ||= object.reactions.select { |reaction| reaction.user_id == scope&.user&.id }.map(&:emoji)
  end

  def edited
    true
  end

  def include_edited?
    object.revisions.any?
  end

  def include_deleted_at?
    !object.deleted_at.nil?
  end

  def include_deleted_by_id?
    !object.deleted_at.nil?
  end

  def include_in_reply_to?
    object.in_reply_to_id.presence
  end

  def reviewable_id
    return @reviewable_id if defined?(@reviewable_id)
    return @reviewable_id = nil unless @options && @options[:reviewable_ids]

    @reviewable_id = @options[:reviewable_ids][object.id]
  end

  def include_reviewable_id?
    reviewable_id.present?
  end

  def user_flag_status
    return @user_flag_status if defined?(@user_flag_status)
    return @user_flag_status = nil unless @options&.dig(:user_flag_statuses)

    @user_flag_status = @options[:user_flag_statuses][object.id]
  end

  def include_user_flag_status?
    user_flag_status.present?
  end
end
